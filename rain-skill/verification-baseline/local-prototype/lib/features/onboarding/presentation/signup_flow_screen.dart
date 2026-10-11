import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/app_router.dart';
import '../../../core/rules/aura_rules.dart';
import '../../../core/theme/aura_colors.dart';
import '../../../core/theme/aura_spacing.dart';
import '../../../core/theme/aura_typography.dart';
import '../../../core/validation/credential_rules.dart';
import '../../../core/validation/username_rules.dart';
import '../../../features/auth/application/auth_providers.dart';
import '../../../features/auth/data/auth_repository.dart';
import '../../../features/auth/data/user_repository.dart';
import '../../../shared/widgets/aura_card.dart';

/// Signup: email → password → age gate → username → review.
///
/// **This diverges from spec §5.3, which asks for phone + OTP.** Phone
/// verification bills per SMS and needs the paid Blaze plan; the beta stays on the
/// free tier, so email and password stand in. The cost is recorded in
/// `aura-mvp-plan.md` — slice 2's contact matching hashes phone numbers, and an
/// email account has none to hash.
///
/// The order is not arbitrary. The age gate runs before Firebase Auth creates an
/// account, so someone who is too young never receives authenticated access.
/// The auth account is created only when the final review is submitted, directly
/// before the atomic profile + username transaction.
///
/// One state worth understanding: a user can be signed in with no
/// `users/{uid}` document, if the app dies between creating the account and
/// writing the profile. [SignupStatus.needsProfile] is that case, and this screen
/// handles it by skipping straight to the age gate rather than trying to create an
/// account whose email is already taken — by them.
class SignupFlowScreen extends ConsumerStatefulWidget {
  const SignupFlowScreen({super.key});

  @override
  ConsumerState<SignupFlowScreen> createState() => _SignupFlowScreenState();
}

/// The steps, named rather than indexed. `_step == 2` in a switch is unreadable
/// and silently wrong the moment a step is inserted.
enum _SignupStep {
  email,
  password,
  birthYear,
  username,
  review;

  bool get isLast => this == _SignupStep.review;
}

class _SignupFlowScreenState extends ConsumerState<SignupFlowScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _birthYearController = TextEditingController();
  final _usernameController = TextEditingController();

  _SignupStep _step = _SignupStep.email;
  String? _error;

  /// True while a network call is in flight. Disables the button and swaps its
  /// label, because two taps on "continue" during a create would try to create
  /// the account twice.
  bool _busy = false;

  bool _obscurePassword = true;

  /// Set once the age gate passes. Drives the minor-safety defaults shown on the
  /// review step, and the `isMinor` flag written to the document.
  AgeGateResult? _ageResult;

  /// The live result for whatever is in the username field right now. Used for
  /// inline feedback and suggestions, *not* as the gate — [_continue] re-checks,
  /// because this is null until the first keystroke.
  UsernameCheck? _usernameDraft;

  /// The name that actually passed shape *and* the availability read. Kept
  /// separate from [_usernameDraft] so the review step cannot be reached holding
  /// a stale or invalid value.
  String? _confirmedUsername;

  @override
  void initState() {
    super.initState();
    // Resume a signup that was interrupted after the auth account existed.
    //
    // This asks the auth repository directly rather than reading
    // [signupStatusProvider], and the difference matters: that provider is built
    // on streams, so on the frame this screen is created it is still
    // [SignupStatus.resolving] and the resume would never fire. `currentUser` is
    // synchronous — Firebase restores the signed-in user from disk before
    // `runApp` — and "an auth account already exists" is exactly the fact that
    // decides whether the email and password steps have anything left to ask.
    //
    // A fully signed-up user who somehow lands here also skips to the age gate
    // and then fails at the end with [AccountProblem.accountAlreadyExists],
    // which is the honest outcome. The splash screen only routes here for
    // [SignupStatus.needsProfile], so that path is not a normal one.
    if (ref.read(authRepositoryProvider).currentUser != null) {
      _step = _SignupStep.birthYear;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _birthYearController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);

    switch (_step) {
      case _SignupStep.email:
        final problem = EmailRules.check(_emailController.text);
        if (problem != null) {
          setState(() => _error = _emailMessage(problem));
          return;
        }

      case _SignupStep.password:
        final problem = PasswordRules.check(_passwordController.text);
        if (problem != null) {
          setState(() => _error = _passwordMessage(problem));
          return;
        }
      case _SignupStep.birthYear:
        final year = int.tryParse(_birthYearController.text.trim());
        if (year == null) {
          setState(() => _error = 'enter your birth year.');
          return;
        }
        final result = evaluateAgeGate(birthYear: year, today: DateTime.now());
        if (!result.canCreateAccount) {
          setState(
            () => _error = switch (result) {
              // Deliberately does not explain the conservative arithmetic. "You
              // are 14 by our maths" invites a retry with a different year.
              AgeGateResult.tooYoung =>
                'you need to be ${AuraAgeRules.minimumAge} or older to use aura.',
              _ => 'that year does not look right.',
            },
          );
          return;
        }
        _ageResult = result;

      case _SignupStep.username:
        if (!await _confirmUsername()) return;

      case _SignupStep.review:
        await _finishSignup();
        return;
    }

    if (!mounted) return;
    setState(() => _step = _SignupStep.values[_step.index + 1]);
  }

  /// Creates the Firebase Auth account. Returns false if it failed, having
  /// already set [_error].
  Future<bool> _createAuthAccount() async {
    // Already signed in — this is the resumed-signup path, or a rebuild after a
    // successful create. Re-creating would fail with email-already-in-use and
    // read to the user as though their own address were someone else's.
    if (ref.read(authRepositoryProvider).currentUser != null) return true;

    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .signUpWithEmail(
            email: _emailController.text,
            password: _passwordController.text,
          );
      return true;
    } on AuthFailure catch (failure) {
      if (!mounted) return false;
      setState(() {
        _error = _authMessage(failure.problem);
        // An address already in use is a mistake made two steps back, so send
        // them there rather than leaving them staring at a password field.
        if (failure.problem == AuthProblem.emailAlreadyInUse) {
          _step = _SignupStep.email;
        }
      });
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Checks shape offline, then reads `usernames/{name}` for availability.
  Future<bool> _confirmUsername() async {
    final check = UsernameRules.check(_usernameController.text);
    switch (check) {
      case UsernameInvalid(:final problem):
        setState(() {
          _usernameDraft = check;
          _error = _usernameMessage(problem);
        });
        return false;
      case UsernameValid(:final normalised):
        setState(() => _busy = true);
        try {
          final free = await ref
              .read(userRepositoryProvider)
              .isUsernameAvailable(normalised);
          if (!mounted) return false;
          if (!free) {
            // §5.3's "suggest alternates if taken" — the suggestion chips are
            // already rendered below for any rejected name, so setting the draft
            // to an invalid state is what surfaces them.
            setState(() {
              _usernameDraft = const UsernameInvalid(UsernameProblem.reserved);
              _error = 'that one is taken. try another.';
            });
            return false;
          }
          _confirmedUsername = normalised;
          return true;
        } on AccountFailure catch (failure) {
          if (!mounted) return false;
          // Cannot tell taken from unreachable, so say neither. Claiming "taken"
          // on a dropped connection would send someone away from a handle that
          // is actually theirs to take.
          setState(() => _error = _accountMessage(failure.problem));
          return false;
        } finally {
          if (mounted) setState(() => _busy = false);
        }
    }
  }

  /// Claims the handle and writes `users/{uid}` in one transaction.
  Future<void> _finishSignup() async {
    final username = _confirmedUsername;
    final birthYear = int.tryParse(_birthYearController.text.trim());

    if (username == null || birthYear == null) {
      // Unreachable by construction — each step assigns its value before it will
      // advance. Handled rather than asserted because a release build with a
      // future reordering bug should show an error, not create a broken account.
      setState(() => _error = 'something went wrong. start again.');
      return;
    }

    // Create credentials only after the age gate and review have passed. A
    // rejected under-age flow therefore never becomes an authenticated account.
    if (!await _createAuthAccount()) return;

    final auth = ref.read(authRepositoryProvider).currentUser;
    if (auth == null) {
      setState(() => _error = 'something went wrong. start again.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(userRepositoryProvider)
          .createAccount(
            uid: auth.uid,
            username: username,
            birthYear: birthYear,
            // From the gate, never recomputed here. Two places doing this arithmetic
            // is two places to get it wrong — and the security rules reject a
            // mismatch between isMinor and birthYear anyway.
            isMinor: _ageResult?.isMinor ?? true,
          );
      if (!mounted) return;
      // Replace, not push: signup is finished and must not be reachable by
      // pressing back into a flow that would try to claim the handle again.
      AppRouter.replaceWith(context, AuraRoutes.home);
    } on AccountFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = _accountMessage(failure.problem);
        // Lost the race with another signup between the availability read and the
        // transaction. Rare, and exactly what the transaction exists to catch.
        if (failure.problem == AccountProblem.usernameTaken) {
          _step = _SignupStep.username;
          _confirmedUsername = null;
          _usernameDraft = const UsernameInvalid(UsernameProblem.reserved);
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    if (_busy) return;
    if (_step == _SignupStep.email) {
      Navigator.of(context).pop();
      return;
    }
    // Deliberately allowed to walk back over the password step even though the
    // auth account now exists. `_createAuthAccount` returns early when already
    // signed in, so a second pass through is a no-op rather than a failed create.
    setState(() {
      _step = _SignupStep.values[_step.index - 1];
      _error = null;
    });
  }

  void _applySuggestion(String suggestion) {
    _usernameController.text = suggestion;
    _usernameController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    setState(() {
      _usernameDraft = UsernameRules.check(suggestion);
      _error = null;
    });
  }

  String _emailMessage(EmailProblem problem) {
    return switch (problem) {
      EmailProblem.empty => 'enter your email.',
      EmailProblem.malformed => 'that does not look like an email.',
    };
  }

  String _passwordMessage(PasswordProblem problem) {
    return switch (problem) {
      PasswordProblem.empty => 'pick a password.',
      PasswordProblem.tooShort =>
        'at least ${PasswordRules.minLength} characters.',
      PasswordProblem.tooSimple => 'mix it up a bit more than that.',
    };
  }

  String _authMessage(AuthProblem problem) {
    return switch (problem) {
      AuthProblem.emailAlreadyInUse => 'that email already has an account.',
      AuthProblem.invalidEmail => 'that does not look like an email.',
      AuthProblem.weakPassword => 'that password is too easy to guess.',
      // Vague on purpose: a precise "no account with that email" turns the login
      // screen into a tool for checking who has an account here.
      AuthProblem.wrongPassword ||
      AuthProblem.userNotFound => 'that email and password do not match.',
      AuthProblem.userDisabled => 'this account has been disabled.',
      AuthProblem.tooManyRequests => 'too many tries. wait a minute.',
      // A configuration fault, not the user's. Says so, because "try again"
      // would send them in circles forever.
      AuthProblem.operationNotAllowed =>
        'email sign-up is not switched on for this app yet.',
      AuthProblem.network => 'no connection. check your internet.',
      AuthProblem.unknown => 'something went wrong. try again.',
    };
  }

  String _accountMessage(AccountProblem problem) {
    return switch (problem) {
      AccountProblem.usernameTaken =>
        'someone just took that one. try another.',
      AccountProblem.accountAlreadyExists => 'you already have an account.',
      AccountProblem.permissionDenied => 'we could not save that. try again.',
      AccountProblem.network => 'no connection. check your internet.',
      AccountProblem.unknown => 'something went wrong. try again.',
    };
  }

  /// Every message names the fix, not the rule. "usernames must match
  /// `^[a-z0-9_]+$`" is true and useless.
  String _usernameMessage(UsernameProblem problem) {
    return switch (problem) {
      UsernameProblem.empty => 'pick a username.',
      UsernameProblem.tooShort =>
        'at least ${UsernameRules.minLength} characters.',
      UsernameProblem.tooLong =>
        'keep it to ${UsernameRules.maxLength} characters.',
      UsernameProblem.badCharacters => 'letters, numbers and _ only.',
      UsernameProblem.mustStartWithLetter => 'start with a letter.',
      UsernameProblem.doubleUnderscore => 'one underscore at a time.',
      UsernameProblem.trailingUnderscore => 'end with a letter or number.',
      UsernameProblem.reserved => 'that one is taken. try another.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'go back',
          onPressed: _busy ? null : _back,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text('join aura', style: AuraType.headingMedium),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AuraSpacing.screenPadding),
          child: Column(
            children: [
              Semantics(
                label:
                    'step ${_step.index + 1} of ${_SignupStep.values.length}',
                child: LinearProgressIndicator(
                  value: (_step.index + 1) / _SignupStep.values.length,
                ),
              ),
              const SizedBox(height: AuraSpacing.xxl),
              Expanded(child: _buildStep()),
              if (_error case final message?) ...[
                const SizedBox(height: AuraSpacing.md),
                // liveRegion so a screen reader announces the failure instead
                // of leaving the user tapping a button that does nothing.
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AuraType.body.copyWith(color: AuraColors.negative),
                  ),
                ),
              ],
              const SizedBox(height: AuraSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _continue,
                  child: Text(
                    _busy
                        ? 'working...'
                        : _step.isLast
                        ? 'finish setup'
                        : 'continue',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep() {
    return switch (_step) {
      _SignupStep.email => _FormStep(
        title: 'what is your email?',
        body: 'we use it to sign you in. nobody else sees it.',
        child: TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          // A capitalised first letter is the single most common way a typed
          // email fails on a phone.
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'email'),
          onSubmitted: (_) => _continue(),
        ),
      ),

      _SignupStep.password => _FormStep(
        title: 'pick a password.',
        body: '${PasswordRules.minLength} characters or more.',
        child: TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          autocorrect: false,
          enableSuggestions: false,
          // newPassword, not password: this is what tells a password manager to
          // offer to generate and save one rather than autofill an old one.
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'password',
            suffixIcon: IconButton(
              // Revealing is allowed on purpose. Forcing a blind retype of a
              // password on a phone keyboard causes more failed signups than it
              // prevents shoulder-surfing.
              tooltip: _obscurePassword ? 'show password' : 'hide password',
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
            ),
          ),
          onSubmitted: (_) => _continue(),
        ),
      ),

      _SignupStep.birthYear => _FormStep(
        title: 'what year were you born?',
        body:
            'aura is ${AuraAgeRules.minimumAge}+. we only store the year, never a full birthday.',
        child: TextField(
          controller: _birthYearController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'birth year',
            counterText: '',
            hintText: 'e.g. 2007',
          ),
          onSubmitted: (_) => _continue(),
        ),
      ),

      _SignupStep.username => _FormStep(
        title: 'pick your handle.',
        body: 'this is how friends find you. lowercase, so nobody can copy it.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _usernameController,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              maxLength: UsernameRules.maxLength,
              decoration: InputDecoration(
                labelText: 'username',
                prefixText: '@',
                counterText: '',
                // Inline tick the moment the name is well-formed. Says "this
                // could work", not "this is free" — availability is the read
                // that happens on continue.
                suffixIcon: switch (_usernameDraft) {
                  UsernameValid() => const Icon(
                    Icons.check_circle_outline,
                    color: AuraColors.positive,
                  ),
                  _ => null,
                },
              ),
              onChanged: (value) => setState(() {
                _usernameDraft = UsernameRules.check(value);
                _error = null;
              }),
              onSubmitted: (_) => _continue(),
            ),
            // §5.3: "suggest alternates if taken". Shown for any rejected name,
            // not only a taken one — someone who typed `Sam!` needs a way
            // forward just as much.
            if (_usernameDraft case UsernameInvalid())
              _UsernameSuggestions(
                raw: _usernameController.text,
                onPick: _applySuggestion,
              ),
          ],
        ),
      ),

      _SignupStep.review => _ReviewStep(
        // Non-null by construction: the username step assigns this before it
        // will advance. `!` rather than a fallback so a future reordering fails
        // loudly in a test instead of shipping a profile called ''.
        username: _confirmedUsername!,
        isMinor: _ageResult?.isMinor ?? true,
      ),
    };
  }
}

/// Tappable alternates from [UsernameRules.suggestionsFor].
///
/// Suffixes are numeric or `_x`-style, never a birth year — appending one would
/// publish the age of a user base that includes minors.
class _UsernameSuggestions extends StatelessWidget {
  const _UsernameSuggestions({required this.raw, required this.onPick});

  final String raw;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final suggestions = UsernameRules.suggestionsFor(raw);
    // Empty for input nothing can be salvaged from (e.g. `!!!`). Rendering a
    // "try these" heading above no chips would look broken.
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AuraSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "free" is a claim we can only make about shape until the read
          // happens, so the wording stays a suggestion rather than a promise.
          Text('these are free:', style: AuraType.bodySmall),
          const SizedBox(height: AuraSpacing.sm),
          Wrap(
            spacing: AuraSpacing.sm,
            runSpacing: AuraSpacing.sm,
            children: [
              for (final suggestion in suggestions)
                ActionChip(
                  label: Text('@$suggestion'),
                  onPressed: () => onPick(suggestion),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FormStep extends StatelessWidget {
  const _FormStep({
    required this.title,
    required this.body,
    required this.child,
  });

  final String title;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text(title, style: AuraType.headingLarge),
        const SizedBox(height: AuraSpacing.sm),
        Text(body, style: AuraType.body.copyWith(color: AuraColors.textMuted)),
        const SizedBox(height: AuraSpacing.xxl),
        child,
      ],
    );
  }
}

/// The last step: what is about to be created, before it is created.
///
/// Naming the minor-safety defaults here is deliberate. A 15-year-old finding
/// out later that they were quietly excluded from leaderboards is a worse
/// experience than being told plainly, once, that it is on and adjustable.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep({required this.username, required this.isMinor});

  final String username;
  final bool isMinor;

  @override
  Widget build(BuildContext context) {
    final caps = AuraRules.pointCapsFor(isMinor: isMinor);

    return ListView(
      children: [
        Text('that is everything.', style: AuraType.headingLarge),
        const SizedBox(height: AuraSpacing.sm),
        Text(
          'here is what your account starts with.',
          style: AuraType.body.copyWith(color: AuraColors.textMuted),
        ),
        const SizedBox(height: AuraSpacing.xl),
        AuraCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('@$username', style: AuraType.headingMedium),
              const SizedBox(height: AuraSpacing.md),
              const _ReviewRow(
                label: 'starting aura',
                value: '${AuraRules.startingScore}',
              ),
              const SizedBox(height: AuraSpacing.sm),
              const _ReviewRow(
                label: 'who can send you aura',
                value: 'friends only',
              ),
              const SizedBox(height: AuraSpacing.sm),
              _ReviewRow(label: 'leaderboards', value: isMinor ? 'off' : 'on'),
              const SizedBox(height: AuraSpacing.sm),
              _ReviewRow(
                label: 'point range',
                value: '${caps.maxNegative} to +${caps.maxPositive}',
              ),
            ],
          ),
        ),
        const SizedBox(height: AuraSpacing.md),
        Text(
          isMinor
              ? 'because you are under 18, leaderboards start off and your point range is tighter. you can change the first one in settings.'
              : 'you can change any of this later in settings.',
          style: AuraType.bodySmall,
        ),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AuraType.bodySmall),
        const SizedBox(width: AuraSpacing.md),
        Text(value, style: AuraType.bodyStrong),
      ],
    );
  }
}
