/// Textos legais da edição Personal (distribuição direta por APK).
/// Revisão por advogado recomendada antes de contratos em escala.
class TextosLegaisPersonal {
  static const String responsavel = 'Murilo da Silva Machado';
  static const String email = 'murilao2012@gmail.com';
  static const String whatsapp = '+55 12 99724-6332';

  static const String termosDeUso = '''
TERMOS DE USO — WORK HOLY PERSONAL

1. FINALIDADE
O Work Holy Personal é uma ferramenta para personal trainers e pequenas
academias organizarem alunos, treinos, horários e registros de atividades.

2. QUEM USA
O aplicativo é licenciado ao profissional ou à academia contratante
("Usuário"). O Usuário é responsável por quem cadastra, pelos treinos que
prescreve e por ter autorização dos alunos para registrar seus dados.

3. RESPONSABILIDADE PROFISSIONAL
O aplicativo é apenas apoio à organização. Não substitui avaliação médica nem
a orientação de profissional de educação física registrado no CREF. A
prescrição dos treinos é de responsabilidade exclusiva do Usuário.

4. DADOS DOS ALUNOS
O Usuário deve informar aos alunos que seus dados são registrados e obter
o consentimento necessário. Dados de saúde (lesões, restrições) são dados
pessoais sensíveis: registre apenas o necessário para o treino.

5. PROPRIEDADE INTELECTUAL
O software é de autoria de $responsavel. É proibido copiar, redistribuir,
revender, descompilar ou modificar o aplicativo sem autorização. Imagens e
descrições de exercícios de terceiros seguem as respectivas licenças.

6. DISTRIBUIÇÃO E ATUALIZAÇÕES
O aplicativo é distribuído por arquivo de instalação (APK) fornecido pelo
responsável, fora de lojas de aplicativos. Atualizações são fornecidas por
novos arquivos de instalação.

7. DISPONIBILIDADE
O aplicativo funciona principalmente sem internet. O backup em nuvem depende
de conexão e de serviços de terceiros (Google Firebase), sem garantia de
disponibilidade ininterrupta. Mantenha o backup ativado e confira-o.

8. CONTATO
$responsavel — $email — WhatsApp $whatsapp.
''';

  static const String politicaPrivacidade = '''
POLÍTICA DE PRIVACIDADE — WORK HOLY PERSONAL

1. QUEM É QUEM
O profissional ou a academia que usa o aplicativo decide quais dados de
alunos registrar e é o responsável por esses dados perante os alunos. O
desenvolvedor ($responsavel) fornece a ferramenta e, quando o backup em
nuvem é ativado, armazena os dados do Usuário na infraestrutura do Google
Firebase, só para permitir a restauração.

2. DADOS TRATADOS
- Conta do Usuário: e-mail e identificador de autenticação.
- Alunos: nome, telefone, objetivo e observações (podem incluir dados de
  saúde, como lesões e restrições).
- Treinos, exercícios, séries realizadas, cargas e tempos.
- Agenda: aluno, data, hora e local do treino.
- Fotos e vídeos de exercícios: ficam SOMENTE no aparelho e não entram no
  backup. Links de vídeo informados entram no backup.

3. ONDE FICAM
Os dados ficam no aparelho do Usuário. Se o Usuário ativar o backup, uma cópia
é enviada ao Google Firebase (Authentication e Firestore), vinculada à conta
dele e acessível apenas por ela, conforme as regras de segurança do projeto.

4. FINALIDADE
Operar o aplicativo, manter a conta e permitir restaurar os dados em caso de
troca ou perda do aparelho. Os dados não são vendidos nem usados para
publicidade.

5. COMPARTILHAMENTO
Os dados não são compartilhados com terceiros, exceto o Google Firebase como
operador do backup e da autenticação.

6. SEUS DIREITOS (LGPD)
O titular pode solicitar confirmação de tratamento, acesso, correção,
anonimização ou exclusão de dados e revogar consentimento. Alunos devem
pedir primeiro ao profissional que os atende; solicitações sobre a conta e o
backup podem ser feitas ao contato abaixo.

7. EXCLUSÃO
Excluir um aluno remove o cadastro do aparelho; o vínculo dos treinos é
desfeito. A cópia em nuvem é atualizada no próximo backup. Para apagar a
conta e o backup em nuvem, solicite ao contato abaixo.

8. SEGURANÇA
A cópia em nuvem é protegida por login e regras de acesso por conta. O Usuário
deve proteger o aparelho com bloqueio de tela e não compartilhar sua senha.

9. CONTATO
$responsavel — $email — WhatsApp $whatsapp.
''';
}
