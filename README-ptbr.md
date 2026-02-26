# Relatório de Uso de Disco de Revendedor cPanel

Readme: [English](README.md)

![Licença](https://img.shields.io/github/license/sr00t3d/cpanel-reseller-usage)
![Script Shell](https://img.shields.io/badge/shell-script-green)

<img width="700" alt="BindFilter" src="cpanel-reseller-usage-cover.webp" />

Um script Bash projetado para administradores de sistemas cPanel/WHM. Ele calcula o uso real de disco (via `du`) para um Revendedor específico e todas as suas subcontas, gerando um relatório de texto formatado.

## 🚀 Funcionalidades

* **Busca de Revendedor:** Identifica automaticamente todas as contas filhas pertencentes a um revendedor específico usando `/etc/trueuserowners`.
* **Cálculo de Uso Real:** Utiliza `du` (uso de disco) varrendo o sistema de arquivos, garantindo um relatório preciso dos tamanhos dos arquivos, mesmo se as cotas do cPanel estiverem fora de sincronia.
* **Saída Formatada:** Gera um arquivo de texto limpo e alinhado com o uso em GB.
* **Acompanhamento de Progresso:** Exibe uma barra de progresso em tempo real durante a execução (útil para revendedores com muitas contas).

## 📋 Pré-requisitos

* **Sistema Operacional:** CentOS/AlmaLinux/CloudLinux com cPanel & WHM instalados.
* **Permissões:** Deve ser executado como `root` para acessar diretórios `/home/` de outros usuários.
* **Dependências:** `bc` (Basic Calculator) deve estar instalado para cálculos com ponto flutuante.
  * Instale via: `yum install bc` ou `apt install bc`.

## 🔧 Uso

1.  Baixe o script para o seu servidor.
2.  Torne-o executável:
    ```bash
    chmod +x cp-reseller-usage.sh
    ```
3.  Execute o script fornecendo o **Nome de Usuário do Revendedor** como argumento:
    ```bash
    ./cp-reseller-usage.sh.sh myreseller
    ```

## 📄 Exemplo de Saída

O script gera um arquivo chamado `usage-report-myreseller.txt` no diretório atual:

```text
Conta          Uso de Disco (GB)
-----------------------------------
client_a              2.45 GB
client_b              0.89 GB
client_c             15.20 GB
-----------------------------------
TOTAL: 18.54 GB
```

## ⚠️ Nota de Desempenho
Como este script executa `du -sm` no diretório home de cada usuário, ele realiza uma varredura real de I/O no sistema de arquivos.
- Revendedores Pequenos/Médios: Executa rapidamente.
- Revendedores Grandes: Se um revendedor tiver centenas de contas ou contas com milhões de arquivos pequenos (inodes), a execução pode levar algum tempo.

## ⚠️ Aviso Legal

> [!WARNING]
> Este software é fornecido "como está". Sempre certifique-se de testar primeiro em um ambiente de desenvolvimento. O autor não é responsável por qualquer uso indevido, consequências legais ou impacto nos dados causados por esta ferramenta.

## 📚 Tutorial Detalhado

Para um guia completo passo a passo, confira meu artigo completo:

👉 [**Verificar tamanho das contas filhas do revendedor no WHM.**](https://perciocastelo.com.br/blog/check-size-of-reseller-child-accounts-in-whm.html)

## Licença 📄

Este projeto está licenciado sob a **GNU General Public License v3.0**. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.
