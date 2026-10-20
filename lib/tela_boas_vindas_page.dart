
import 'package:flutter/material.dart';

class TelaBoasVindasPage extends StatelessWidget {
  const TelaBoasVindasPage({
    super.key,
    required this.onComecar,
  });

  final VoidCallback onComecar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: const Color(0xFFB7F34A),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 58,
                  color: Color(0xFF10120F),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'WorkHoly',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Seu treino. Sua evolução.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: cores.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Organize seus treinos, acompanhe suas sessões '
                'e acompanhe sua evolução em um só lugar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: cores.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onComecar,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text(
                      'Começar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Seu próximo passo começa aqui.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: cores.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
