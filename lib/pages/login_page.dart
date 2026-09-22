import 'package:flutter/material.dart';

import '../services/auth_services.dart';

class LoginPage extends StatefulWidget {
	const LoginPage({super.key, required this.authService});

	final AuthService authService;

	@override
	State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
	final _formKey = GlobalKey<FormState>();
	final _emailController = TextEditingController();
	final _passwordController = TextEditingController();
	bool _isLogin = true;
	bool _isLoading = false;

	@override
	void dispose() {
		_emailController.dispose();
		_passwordController.dispose();
		super.dispose();
	}

	Future<void> _submit() async {
		if (!_formKey.currentState!.validate()) return;

		setState(() => _isLoading = true);
		try {
			if (_isLogin) {
				await widget.authService.login(
					_emailController.text.trim(),
					_passwordController.text,
				);
			} else {
				await widget.authService.registrar(
					_emailController.text.trim(),
					_passwordController.text,
				);
			}
		} on AuthException catch (error) {
			if (!mounted) return;
			ScaffoldMessenger.of(context).showSnackBar(
				SnackBar(content: Text(error.message)),
			);
		} finally {
			if (mounted) setState(() => _isLoading = false);
		}
	}

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			body: Center(
				child: SingleChildScrollView(
					padding: const EdgeInsets.all(24),
					child: Form(
						key: _formKey,
						child: Column(
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(
									_isLogin ? 'Bem-vindo' : 'Crie sua conta',
									style: Theme.of(context).textTheme.headlineMedium,
								),
								const SizedBox(height: 32),
								TextFormField(
									controller: _emailController,
									keyboardType: TextInputType.emailAddress,
									decoration: const InputDecoration(
										border: OutlineInputBorder(),
										labelText: 'Email',
									),
									validator: (value) =>
											value == null || value.trim().isEmpty
													? 'Informe o email.'
													: null,
								),
								const SizedBox(height: 16),
								TextFormField(
									controller: _passwordController,
									obscureText: true,
									decoration: const InputDecoration(
										border: OutlineInputBorder(),
										labelText: 'Senha',
									),
									validator: (value) =>
											value == null || value.length < 6
													? 'A senha deve ter no mínimo 6 caracteres.'
													: null,
								),
								const SizedBox(height: 24),
								SizedBox(
									width: double.infinity,
									child: ElevatedButton(
										onPressed: _isLoading ? null : _submit,
										child: _isLoading
												? const SizedBox(
														height: 20,
														width: 20,
														child: CircularProgressIndicator(strokeWidth: 2),
													)
												: Text(_isLogin ? 'Entrar' : 'Cadastrar'),
									),
								),
								TextButton(
									onPressed: _isLoading
											? null
											: () => setState(() => _isLogin = !_isLogin),
									child: Text(
										_isLogin
												? 'Ainda não tem conta? Cadastre-se.'
												: 'Já tem uma conta? Entrar.',
									),
								),
							],
						),
					),
				),
			),
		);
	}
}
