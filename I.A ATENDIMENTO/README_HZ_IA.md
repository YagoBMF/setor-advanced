# HZ IA - Atualizacao automatica

## Estrutura no repositorio

Envie a pasta `HZ_IA` para a raiz do repositorio `setor-advanced`.

Arquivos publicados:

- `HZ_IA/PC/HZ_ATENDIMENTO_IA.lua`
- `HZ_IA/PC/HZ_IA_UPDATER.lua`
- `HZ_IA/PC/versao.txt`

Nunca envie `hz_ai_config.lua`, chaves ou senhas ao GitHub.

## Primeira instalacao da staff

Coloque `HZ_ATENDIMENTO_IA.lua` e `HZ_IA_UPDATER.lua` na pasta MoonLoader. O atualizador migra automaticamente a chave que estiver numa versao antiga do mod para `MoonLoader/config/hz_ai_config.lua`.

Para uma instalacao nova, copie `hz_ai_config.example.lua` para `MoonLoader/config/hz_ai_config.lua` e preencha a chave.

## Publicar nova versao

1. Teste o mod localmente.
2. Altere `script_version` em `HZ_ATENDIMENTO_IA.lua`.
3. Envie primeiro o novo `HZ_ATENDIMENTO_IA.lua` ao GitHub.
4. Confirme o arquivo no link RAW.
5. Por ultimo, coloque a mesma versao em `versao.txt`.

## Comandos

- `/hzaiversao`: mostra a versao e consulta atualizacoes.
- `/hzaiatualizar`: baixa novamente a versao publicada.
- `/hzairollback`: restaura o ultimo backup.
