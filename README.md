# Rancho Rebelato

Aplicativo Flutter para gerenciar oficinas, turmas, matrículas e despesas do Rancho Rebelato. O app usa Firebase Authentication para login e Cloud Firestore para os dados.

## Configuração do Firebase

O app está conectado ao projeto Firebase `rancho-rebelato-app`. O banco Firestore `(default)` já está criado em `southamerica-east1` (São Paulo), e as regras e índices deste repositório já foram publicados.

1. Em **Authentication > Sign-in method**, mantenha Email/Senha habilitado.
2. Crie o documento `organizations/rancho-rebelato` no Firestore, com pelo menos o campo `name` igual a `Rancho Rebelato`.
3. A primeira conta administradora deve ser criada manualmente em `organizations/rancho-rebelato/members/{UID}` com `role: "admin"`, `displayName`, `email` e `createdAt` (timestamp).
4. Novas contas criadas pelo app ganham automaticamente um perfil `viewer`. Admin e coordenação podem mudar o perfil na seção **Usuários** da página inicial.

Novas contas só podem criar o próprio perfil inicial com papel `viewer`; não podem conceder permissões elevadas a si mesmas. As regras continuam protegendo as alterações de perfil no servidor.

## Estrutura inicial

Todos os dados pertencem à organização `rancho-rebelato`:

```text
organizations/{orgId}
  members/{uid}                         role e dados básicos do usuário
  classes/{classId}                     oficina/turma e instrutor responsável
    enrollments/{enrollmentId}           matrícula na turma
  students/{studentId}                   cadastro do aluno
  expenses/{expenseId}                   despesa e categoria
```

Despesas guardam `amountCents` como inteiro (centavos, sem ponto flutuante) e `occurredAt` como timestamp. O serviço calcula total e subtotais por categoria para o mês selecionado.

Cadastros de alunos incluem `fullName`, `cpf`, `birthDate`, `phone`, `address`, `guardianName`, `guardianRelationship`, `guardianCpf`, `guardianPhone` e `isActive`. Campos novos são compatíveis com documentos antigos que ainda não os possuem; ao editar, os dados adicionais serão gravados.

## Perfis e permissões

| Perfil | Permissões |
| --- | --- |
| `admin` | Lê e gerencia todos os dados e membros; edita/exclui despesas |
| `coordinator` | Gerencia oficinas, turmas, alunos, matrículas e perfis de usuários; registra despesas |
| `instructor` | Lê somente suas turmas e as matrículas dessas turmas |
| `viewer` | Consulta dados gerais, mas não acessa cadastros pessoais dos alunos |

As regras estão em `firestore.rules`; a autorização efetiva é aplicada no servidor.

## Telas disponíveis

Após o usuário entrar, contas sem perfil recebem automaticamente `viewer`. A tela inicial mostra atalhos para turmas, alunos e despesas; admin e coordenação também veem **Usuários**, onde podem alterar perfis. Admin e coordenação podem criar, editar e excluir turmas, matricular e editar matrículas, cadastrar e editar alunos e alternar o status ativo dos alunos e turmas. A exclusão do cadastro de um aluno preserva as matrículas históricas. O status do cadastro do aluno e o status da matrícula são campos separados; alterar um não altera o outro. A exclusão de uma turma também remove suas matrículas. Somente administradores podem editar ou excluir despesas; admin e coordenação podem registrar despesas. A listagem de alunos permite busca por nome, responsável ou CPF e filtro por ativos/inativos. O resumo mostra turmas e alunos ativos e o total de despesas do mês, com detalhamento por categoria. Instrutores veem somente as turmas atribuídas a eles e suas matrículas; usuários `viewer` consultam dados gerais, mas cadastros com dados pessoais de alunos são restritos a administradores e coordenação.

Ao cadastrar uma turma pelo app, informe o UID da conta que tem o perfil `instructor`. As despesas são digitadas em reais na tela e salvas como centavos inteiros no Firestore.
