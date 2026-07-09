import 'package:flutter/material.dart';
import 'package:frontend_poc_arrow/core/localization/l10n/app_localizations.dart';

import '../../../core/theme/app_theme.dart';
import '../../progress/infrastructure/local_progress_dependencies.dart';
import '../infrastructure/auth_dependencies.dart';
import 'auth_screen_controller.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({this.controller, super.key});

  final AuthScreenController? controller;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AuthScreenController? _controller;

  @override
  void initState() {
    super.initState();
    final provided = widget.controller;
    if (provided != null) {
      _controller = provided;
      return;
    }
    _createController();
  }

  Future<void> _createController() async {
    final controller = AuthScreenController(
      login: await AuthDependencies.createLoginUseCase(),
      register: await AuthDependencies.createRegisterUseCase(),
      syncProgressOnLogin:
          (await LocalProgressDependencies.createSyncProgressOnLoginUseCase())
              .call,
    );
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() => _controller = controller);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    if (widget.controller == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.login)),
      body: SafeArea(
        child: controller == null
            ? const Center(child: CircularProgressIndicator())
            : AnimatedBuilder(
                animation: controller,
                builder: (context, _) {
                  if (controller.status == AuthScreenStatus.success) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && Navigator.of(context).canPop()) {
                        Navigator.of(context).pop(true);
                      }
                    });
                  }
                  return _AuthForm(
                    controller: controller,
                    displayNameController: _displayNameController,
                    emailController: _emailController,
                    passwordController: _passwordController,
                  );
                },
              ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.controller,
    required this.displayNameController,
    required this.emailController,
    required this.passwordController,
  });

  final AuthScreenController controller;
  final TextEditingController displayNameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final isRegister = controller.mode == AuthMode.register;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRegister ? localizations.register : localizations.login,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(localizations.authOptional),
                const SizedBox(height: 20),
                if (isRegister) ...[
                  TextField(
                    controller: displayNameController,
                    decoration: InputDecoration(
                      labelText: localizations.displayName,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(labelText: localizations.email),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: localizations.password,
                  ),
                ),
                if (controller.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    controller.errorMessage!,
                    style: const TextStyle(color: AppTheme.pastelAmber),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: controller.status == AuthScreenStatus.submitting
                      ? null
                      : () => controller.submit(
                          displayName: displayNameController.text,
                          email: emailController.text,
                          password: passwordController.text,
                        ),
                  child: Text(
                    controller.status == AuthScreenStatus.submitting
                        ? localizations.loadingSettings
                        : localizations.submit,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: controller.toggleMode,
                  child: Text(
                    isRegister ? localizations.login : localizations.register,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
