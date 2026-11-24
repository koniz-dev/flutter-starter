import 'package:flutter/widgets.dart';
import 'package:flutter_starter/features/auth/domain/repositories/auth_repository.dart';
import 'package:flutter_starter/features/auth/domain/usecases/login_usecase.dart';
import 'package:provider/provider.dart';

AuthRepository _repository() => throw UnimplementedError();

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const SizedBox();
}

// Step 4 "After (Provider)" from the doc, verbatim apart from the
// AuthRepositoryImpl(...) placeholder.
void main() {
  runApp(
  MultiProvider(
    providers: [
      Provider<AuthRepository>(create: (_) => _repository()),
      ProxyProvider<AuthRepository, LoginUseCase>(
        update: (_, repository, _) => LoginUseCase(repository),
      ),
    ],
    child: const MyApp(),
  ),

  );
}
