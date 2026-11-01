import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shogunify/controllers/auth_controller.dart';
import 'package:shogunify/pages/home.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  static const _background = Color.fromARGB(255, 18, 18, 18);
  static const _surface = Color.fromARGB(255, 27, 27, 27);
  static const _purple = Color.fromARGB(255, 72, 61, 115);
  static const _purpleBright = Color.fromARGB(255, 147, 132, 209);

  final _formKey = GlobalKey<FormState>();
  final _inviteCodeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _inviteFocus = FocusNode();
  final _usernameFocus = FocusNode();

  bool _isSignUp = false;
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _usernameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    _usernameController.dispose();
    _inviteFocus.dispose();
    _usernameFocus.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }

  void _setMode(bool signUp) {
    if (_isSignUp == signUp || _isSubmitting) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSignUp = signUp;
      _errorText = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      (signUp ? _usernameFocus : _usernameFocus).requestFocus();
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _clearError();

    // Sign Up: check the invite code locally first. It's a fixed value, so a
    // typo can be caught instantly without a round trip to the server.
    if (_isSignUp &&
        _inviteCodeController.text.trim() != AuthController.defaultInviteCode) {
      setState(() => _errorText = 'That invite code is incorrect.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final auth = Provider.of<AuthController>(context, listen: false);
      // Log In sends the shared code silently — the user never types it.
      // Sign Up sends exactly what they typed (already verified above).
      final inviteCode = _isSignUp
          ? _inviteCodeController.text.trim()
          : AuthController.defaultInviteCode;

      final error = await auth.login(
        _usernameController.text.trim(),
        inviteCode,
      );

      if (!mounted) return;

      if (error == null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const Home()),
        );
      } else {
        setState(() => _errorText = error);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required VoidCallback onClear,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: Colors.white70),
      suffixIcon: IconButton(
        tooltip: 'Clear $label',
        onPressed: () {
          onClear();
          _clearError();
        },
        icon: const Icon(Icons.close_rounded, color: Colors.white38),
      ),
      filled: true,
      fillColor: _surface,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      errorStyle: const TextStyle(
        color: Color.fromARGB(255, 255, 137, 137),
        fontWeight: FontWeight.w600,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _purpleBright, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  Widget _buildBrand() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _purple,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _purpleBright.withValues(alpha: 0.55)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/images/Icon6.jpg',
              width: 48,
              height: 48,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Shogunify',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Expanded(child: _buildModeSegment('Log In', signUp: false)),
          Expanded(child: _buildModeSegment('Sign Up', signUp: true)),
        ],
      ),
    );
  }

  Widget _buildModeSegment(String label, {required bool signUp}) {
    final active = _isSignUp == signUp;
    return GestureDetector(
      onTap: () => _setMode(signUp),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: active ? _purpleBright : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white60,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSignUp ? 'Create your account' : 'Welcome back',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isSignUp
              ? 'Enter the invite code your friend gave you and pick a username.'
              : 'Enter the username you signed up with.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _usernameController,
          focusNode: _usernameFocus,
          textInputAction: _isSignUp
              ? TextInputAction.next
              : TextInputAction.done,
          autofillHints: const [AutofillHints.username],
          style: const TextStyle(color: Colors.white, fontSize: 17),
          decoration: _fieldDecoration(
            label: 'Username',
            hint: 'Enter your display name',
            icon: Icons.person_outline_rounded,
            onClear: _usernameController.clear,
          ),
          onChanged: (_) => _clearError(),
          onFieldSubmitted: (_) {
            if (_isSignUp) {
              _inviteFocus.requestFocus();
            } else {
              _submit();
            }
          },
          validator: (value) {
            final username = value?.trim() ?? '';
            if (username.isEmpty) return 'Please enter your username';
            if (username.length < 2) return 'Use at least 2 characters';
            return null;
          },
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          child: _isSignUp
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextFormField(
                    controller: _inviteCodeController,
                    focusNode: _inviteFocus,
                    textInputAction: TextInputAction.done,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                    decoration: _fieldDecoration(
                      label: 'Invite code',
                      hint: 'Type the code you received',
                      icon: Icons.key_rounded,
                      onClear: _inviteCodeController.clear,
                    ),
                    onChanged: (_) => _clearError(),
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        _isSignUp && (value == null || value.trim().isEmpty)
                        ? 'Please enter your invite code'
                        : null,
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _purpleBright,
          foregroundColor: Colors.black,
          disabledBackgroundColor: _purple.withValues(alpha: 0.55),
          disabledForegroundColor: Colors.white60,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Please wait...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp ? 'Create Account' : 'Log In',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 21),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBrand(),
                    const SizedBox(height: 34),
                    _buildModeToggle(),
                    const SizedBox(height: 28),
                    _buildForm(),
                    if (_errorText != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.55),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _buildActionButton(),
                    const SizedBox(height: 24),
                    const Text(
                      'Music is better together.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white38, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// import 'dart:math';

// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:shogunify/controllers/auth_controller.dart';
// import 'package:shogunify/pages/home.dart';

// class Login extends StatefulWidget {
//   const Login({super.key});

//   @override
//   State<Login> createState() => _LoginState();
// }

// class _LoginState extends State<Login> {
//   static const _background = Color.fromARGB(255, 18, 18, 18);
//   static const _surface = Color.fromARGB(255, 27, 27, 27);
//   static const _purple = Color.fromARGB(255, 72, 61, 115);
//   static const _purpleBright = Color.fromARGB(255, 147, 132, 209);

//   final _formKey = GlobalKey<FormState>();
//   final _inviteCodeController = TextEditingController();
//   final _usernameController = TextEditingController();
//   final _inviteFocus = FocusNode();
//   final _usernameFocus = FocusNode();

//   final _avatarColors = const [
//     Color.fromARGB(255, 72, 61, 115),
//     Color.fromARGB(255, 104, 74, 130),
//     Color.fromARGB(255, 75, 111, 92),
//     Color.fromARGB(255, 125, 82, 82),
//     Color.fromARGB(255, 137, 91, 58),
//     Color.fromARGB(255, 72, 61, 115),
//   ];

//   int _step = 0;
//   bool _isSubmitting = false;
//   String? _errorText;
//   late Color _avatarColor;

//   @override
//   void initState() {
//     super.initState();
//     _avatarColor = _randomAvatarColor();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) _inviteFocus.requestFocus();
//     });
//   }

//   Color _randomAvatarColor() {
//     return _avatarColors[Random().nextInt(_avatarColors.length)];
//   }

//   @override
//   void dispose() {
//     _inviteCodeController.dispose();
//     _usernameController.dispose();
//     _inviteFocus.dispose();
//     _usernameFocus.dispose();
//     super.dispose();
//   }

//   void _clearError() {
//     if (_errorText != null) setState(() => _errorText = null);
//   }

//   bool _validateCurrentStep() {
//     FocusScope.of(context).unfocus();
//     final valid = _formKey.currentState?.validate() ?? false;
//     if (valid) _clearError();
//     return valid;
//   }

//   void _nextStep() {
//     if (!_validateCurrentStep()) return;

//     setState(() {
//       _step += 1;
//       if (_step == 2) _avatarColor = _randomAvatarColor();
//     });

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!mounted) return;
//       if (_step == 1) {
//         _usernameFocus.requestFocus();
//       }
//     });
//   }

//   void _previousStep() {
//     if (_step == 0 || _isSubmitting) return;
//     FocusScope.of(context).unfocus();
//     setState(() {
//       _step -= 1;
//       _errorText = null;
//     });
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (mounted) {
//         (_step == 0 ? _inviteFocus : _usernameFocus).requestFocus();
//       }
//     });
//   }

//   Future<void> _submit() async {
//     if (_isSubmitting || !_validateCurrentStep()) return;

//     setState(() {
//       _isSubmitting = true;
//       _errorText = null;
//     });

//     try {
//       final auth = Provider.of<AuthController>(context, listen: false);
//       final error = await auth.login(
//         _usernameController.text.trim(),
//         _inviteCodeController.text.trim(),
//       );

//       if (!mounted) return;

//       if (error == null) {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const Home()),
//         );
//       } else {
//         setState(() => _errorText = error);
//       }
//     } catch (_) {
//       if (mounted) {
//         setState(() => _errorText = 'Unable to sign in. Please try again.');
//       }
//     } finally {
//       if (mounted) setState(() => _isSubmitting = false);
//     }
//   }

//   InputDecoration _fieldDecoration({
//     required String label,
//     required String hint,
//     required IconData icon,
//   }) {
//     return InputDecoration(
//       labelText: label,
//       hintText: hint,
//       prefixIcon: Icon(icon, color: Colors.white70),
//       suffixIcon: IconButton(
//         tooltip: 'Clear $label',
//         onPressed: () {
//           if (label == 'Invite code') {
//             _inviteCodeController.clear();
//           } else {
//             _usernameController.clear();
//           }
//           _clearError();
//         },
//         icon: const Icon(Icons.close_rounded, color: Colors.white38),
//       ),
//       filled: true,
//       fillColor: _surface,
//       labelStyle: const TextStyle(color: Colors.white70),
//       hintStyle: const TextStyle(color: Colors.white38),
//       errorStyle: const TextStyle(
//         color: Color.fromARGB(255, 255, 137, 137),
//         fontWeight: FontWeight.w600,
//       ),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(16),
//         borderSide: const BorderSide(color: Colors.white24),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(16),
//         borderSide: const BorderSide(color: _purpleBright, width: 2),
//       ),
//       errorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(16),
//         borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
//       ),
//       focusedErrorBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(16),
//         borderSide: const BorderSide(color: Colors.redAccent, width: 2),
//       ),
//     );
//   }

//   String get _avatarLetter {
//     final value = _usernameController.text.trim();
//     return value.isEmpty ? '?' : value.characters.first.toUpperCase();
//   }

//   Widget _buildBrand() {
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Container(
//           width: 48,
//           height: 48,
//           decoration: BoxDecoration(
//             color: _purple,
//             borderRadius: BorderRadius.circular(15),
//             border: Border.all(color: _purpleBright.withValues(alpha: 0.55)),
//           ),
//           child: ClipRRect(
//             borderRadius: BorderRadius.circular(14),
//             child: Image.asset(
//               'assets/images/Icon6.jpg',
//               width: 48,
//               height: 48,
//               fit: BoxFit.cover,
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         const Text(
//           'Shogunify',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 22,
//             fontWeight: FontWeight.w800,
//             letterSpacing: -0.4,
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _buildProgress() {
//     return Row(
//       children: List.generate(3, (index) {
//         final active = index == _step;
//         return Expanded(
//           child: AnimatedContainer(
//             duration: const Duration(milliseconds: 220),
//             height: 4,
//             margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
//             decoration: BoxDecoration(
//               color: index <= _step ? _purpleBright : Colors.white24,
//               borderRadius: BorderRadius.circular(8),
//             ),
//             child: active ? const SizedBox.shrink() : null,
//           ),
//         );
//       }),
//     );
//   }

//   Widget _buildInviteStep() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'Enter your invite code',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 29,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 10),
//         const Text(
//           'This keeps Shogunify listening-ready for your crew.',
//           style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
//         ),
//         const SizedBox(height: 26),
//         TextFormField(
//           controller: _inviteCodeController,
//           focusNode: _inviteFocus,
//           textInputAction: TextInputAction.next,
//           textCapitalization: TextCapitalization.none,
//           style: const TextStyle(color: Colors.white, fontSize: 17),
//           decoration: _fieldDecoration(
//             label: 'Invite code',
//             hint: 'Type the code you received',
//             icon: Icons.key_rounded,
//           ),
//           onChanged: (_) => _clearError(),
//           onFieldSubmitted: (_) => _nextStep(),
//           validator: (value) => value == null || value.trim().isEmpty
//               ? 'Please enter your invite code'
//               : null,
//         ),
//         const SizedBox(height: 12),
//         const Row(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Icon(Icons.info_outline_rounded, color: Colors.white54, size: 18),
//             SizedBox(width: 8),
//             Expanded(
//               child: Text(
//                 'Ask Wannuwat for the invite code if you do not have one yet.',
//                 style: TextStyle(
//                   color: Colors.white54,
//                   fontSize: 13,
//                   height: 1.35,
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   Widget _buildUsernameStep() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Text(
//           'What should we call you?',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 29,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 10),
//         const Text(
//           'Choose a name your friends will recognize in the room.',
//           style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
//         ),
//         const SizedBox(height: 26),
//         TextFormField(
//           controller: _usernameController,
//           focusNode: _usernameFocus,
//           textInputAction: TextInputAction.done,
//           autofillHints: const [AutofillHints.username],
//           style: const TextStyle(color: Colors.white, fontSize: 17),
//           decoration: _fieldDecoration(
//             label: 'Username',
//             hint: 'Enter your display name',
//             icon: Icons.person_outline_rounded,
//           ),
//           onChanged: (_) => _clearError(),
//           onFieldSubmitted: (_) => _nextStep(),
//           validator: (value) {
//             final username = value?.trim() ?? '';
//             if (username.isEmpty) return 'Please enter your username';
//             if (username.length < 2) return 'Use at least 2 characters';
//             return null;
//           },
//         ),
//       ],
//     );
//   }

//   Widget _buildAvatarStep() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.center,
//       children: [
//         const Text(
//           'Make it yours',
//           style: TextStyle(
//             color: Colors.white,
//             fontSize: 29,
//             fontWeight: FontWeight.bold,
//           ),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 10),
//         const Text(
//           'Your Shogunify profile picture is ready.\nYou can change it later in settings.',
//           textAlign: TextAlign.center,
//           style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
//         ),
//         const SizedBox(height: 28),
//         Container(
//           width: 132,
//           height: 132,
//           decoration: BoxDecoration(
//             color: _avatarColor,
//             shape: BoxShape.circle,
//             boxShadow: [
//               BoxShadow(
//                 color: _avatarColor.withValues(alpha: 0.38),
//                 blurRadius: 28,
//                 spreadRadius: 4,
//               ),
//             ],
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             _avatarLetter,
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 58,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ),
//         const SizedBox(height: 20),
//         Text(
//           _usernameController.text.trim(),
//           style: const TextStyle(
//             color: Colors.white,
//             fontSize: 20,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         const SizedBox(height: 6),
//         const Text(
//           'A fresh color is picked for your avatar.',
//           style: TextStyle(color: Colors.white54, fontSize: 13),
//         ),
//       ],
//     );
//   }

//   Widget _buildActionButton() {
//     final isLastStep = _step == 2;
//     return SizedBox(
//       width: double.infinity,
//       height: 56,
//       child: ElevatedButton(
//         onPressed: _isSubmitting ? null : (isLastStep ? _submit : _nextStep),
//         style: ElevatedButton.styleFrom(
//           backgroundColor: _purpleBright,
//           foregroundColor: Colors.white,
//           disabledBackgroundColor: _purple.withValues(alpha: 0.55),
//           disabledForegroundColor: Colors.white60,
//           elevation: 0,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16),
//           ),
//         ),
//         child: _isSubmitting
//             ? const Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   SizedBox(
//                     width: 20,
//                     height: 20,
//                     child: CircularProgressIndicator(
//                       strokeWidth: 2.4,
//                       color: Colors.white,
//                     ),
//                   ),
//                   SizedBox(width: 12),
//                   Text(
//                     'Signing in...',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//                   ),
//                 ],
//               )
//             : Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Text(
//                     isLastStep ? 'Enter Shogunify' : 'Next',
//                     style: const TextStyle(
//                       fontSize: 17,
//                       fontWeight: FontWeight.bold,
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   Icon(
//                     isLastStep
//                         ? Icons.check_rounded
//                         : Icons.arrow_forward_rounded,
//                     size: 21,
//                   ),
//                 ],
//               ),
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: _background,
//       body: SafeArea(
//         child: Center(
//           child: SingleChildScrollView(
//             padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
//             child: ConstrainedBox(
//               constraints: const BoxConstraints(maxWidth: 460),
//               child: Form(
//                 key: _formKey,
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     _buildBrand(),
//                     const SizedBox(height: 34),
//                     _buildProgress(),
//                     const SizedBox(height: 14),
//                     Text(
//                       'STEP ${_step + 1} OF 3',
//                       style: const TextStyle(
//                         color: Colors.white54,
//                         fontSize: 11,
//                         fontWeight: FontWeight.bold,
//                         letterSpacing: 1.5,
//                       ),
//                     ),
//                     const SizedBox(height: 28),
//                     AnimatedSwitcher(
//                       duration: const Duration(milliseconds: 220),
//                       transitionBuilder: (child, animation) => FadeTransition(
//                         opacity: animation,
//                         child: SlideTransition(
//                           position: Tween<Offset>(
//                             begin: const Offset(0.04, 0),
//                             end: Offset.zero,
//                           ).animate(animation),
//                           child: child,
//                         ),
//                       ),
//                       child: KeyedSubtree(
//                         key: ValueKey(_step),
//                         child: _step == 0
//                             ? _buildInviteStep()
//                             : _step == 1
//                             ? _buildUsernameStep()
//                             : _buildAvatarStep(),
//                       ),
//                     ),
//                     if (_errorText != null) ...[
//                       const SizedBox(height: 18),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 14,
//                           vertical: 12,
//                         ),
//                         decoration: BoxDecoration(
//                           color: Colors.redAccent.withValues(alpha: 0.12),
//                           borderRadius: BorderRadius.circular(12),
//                           border: Border.all(
//                             color: Colors.redAccent.withValues(alpha: 0.55),
//                           ),
//                         ),
//                         child: Row(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             const Icon(
//                               Icons.error_outline_rounded,
//                               color: Colors.redAccent,
//                               size: 20,
//                             ),
//                             const SizedBox(width: 10),
//                             Expanded(
//                               child: Text(
//                                 _errorText!,
//                                 style: const TextStyle(
//                                   color: Colors.redAccent,
//                                   height: 1.35,
//                                 ),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ],
//                     const SizedBox(height: 28),
//                     _buildActionButton(),
//                     const SizedBox(height: 12),
//                     if (_step > 0)
//                       TextButton.icon(
//                         onPressed: _isSubmitting ? null : _previousStep,
//                         icon: const Icon(Icons.arrow_back_rounded, size: 18),
//                         label: const Text('Back'),
//                         style: TextButton.styleFrom(
//                           foregroundColor: Colors.white60,
//                         ),
//                       )
//                     else
//                       const SizedBox(height: 40),
//                     const SizedBox(height: 4),
//                     const Text(
//                       'Music is better together.',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(color: Colors.white38, fontSize: 13),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
