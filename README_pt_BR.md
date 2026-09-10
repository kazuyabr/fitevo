<div align="center">

<img src="assets/logo/logo.png" alt="Logo do Fitevo" width="140" />

# Fitevo

**Um app gratuito, offline-first, de fitness, nutrição e acompanhamento de treinos para iniciantes na academia.**

Registre uma refeição em uma frase. Veja tudo de uma vez.
Construído com Flutter, Firebase e IA Groq / Gemini.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](#licença)

</div>

---

## Por que o Fitevo

A maioria dos apps de fitness bloqueia o que importa atrás de paywall e te sufoca em fricção. O Fitevo faz o contrário:

- **Registro em uma frase.** Digite *"2 tortillas e um prato de feijão"* — a IA interpreta, estima a nutrição e atualiza seus anéis.
- **Tudo visível de uma vez.** Calorias, macros, água, fibra, sódio — sem rolar a tela, sem abas.
- **Modelo de adequação, não restrição.** Preencha barras *em direção* a um alvo. Sem vermelho "você passou do limite", sem julgamento.
- **Estimativas honestas.** A incerteza da IA é mostrada como uma faixa, não como precisão falsa.
- **Segurança embutida no cálculo.** Piso calórico + limite de ritmo de mudança de peso aplicados em todo o app.
- **Offline-first.** Seus dados ficam no celular no Isar. Sincronização com Firestore é opcional.
- **100% gratuito, sem cartão de crédito** para qualquer serviço — apenas tiers gratuitos do Gemini, Groq, USDA e Firebase.

---

## Funcionalidades

### Nutrição
- Registro de alimentos por linguagem natural com IA (entrada em uma frase → registro estruturado)
- Registro por foto da câmera ou galeria com IA (multimodal Llama / Gemini)
- Anéis e barras de adequação para calorias, proteínas, carboidratos, gorduras, fibra, água e sódio
- "O que devo comer?" — a IA sugere refeições que cabem nos seus macros *restantes*
- Alimentos e receitas personalizadas com re-registro em um toque
- Favoritos e re-registro rápido a partir de refeições recentes
- Escala rápida de porções (`0.5× / 1× / 1.5× / 2×`) em qualquer item registrado
- Consulta cruzada com USDA FoodData Central para estimativas de IA de baixa confiança

### Treinos
- Rotinas iniciais geradas por IA a partir do seu objetivo e dias de treino por semana
- Construtor manual de rotinas com seletor de exercícios (busca na biblioteca + nomes personalizados)
- Resolvedor "o que treinar hoje" baseado no dia da semana ou no grupo muscular mais descansado
- Registro de séries com **números da sessão anterior em tempo real** por série
- Timer de descanso com contagem regressiva + barra de progresso + vibração
- **Detecção automática de PR** (Epley 1-RM) com toast de celebração
- Página de recordes pessoais ordenados por recente
- Dicas de sobrecarga progressiva por exercício
- Chips de volume semanal por grupo muscular
- Estimativa de calorias por sessão baseada em MET
- Menu de segurança para descartar treino
- Guias de exercícios para iniciantes — dicas de forma + avisos de erros comuns

### Progresso
- Registro de medições corporais (gordura %, cintura / peito / braço / coxa) + fotos de progresso privadas no dispositivo
- Gráfico de linha de peso com média móvel de 7 dias e variação da tendência
- **Metas adaptativas** — alvos diários recalculados a partir da média móvel do peso, limitados por limites de ritmo saudáveis
- Gráfico de barras de calorias de 14 dias com linha de alvo
- Gráfico de progressão de força por exercício (1-RM estimado ao longo do tempo)
- Contador de sequência (registro de refeição ou treino conta como um dia)
- Seis badges desbloqueáveis
- Fotos de progresso em galeria privada, zoom em tela cheia

### Coach
- Chat com coach de IA, consciente de iniciantes, solidário, respeitoso de limites
- Revisão semanal de IA resumindo conquistas + 1–2 pequenos ajustes
- Gerador de sugestões de refeições a partir dos macros restantes

### Lembretes e Sincronização
- Lembretes de água em intervalos de 1 / 2 / 3 / 4 horas durante o horário de vigília
- Lembretes de refeições em horários editáveis de café da manhã / almoço / jantar
- Tela de sincronização manual com band para passos / frequência cardíaca / sono (Huawei Health, Mi Fit, etc.)

### Privacidade e Dados
- Armazenamento offline-first no Isar — funciona totalmente offline
- Autenticação Firebase opcional (login com Google, e-mail/senha ou anônimo + upgrade posterior)
- Backup na nuvem com Firestore opcional
- **Fotos de progresso e medições corporais nunca são sincronizadas** — permanecem no dispositivo
- Exportação JSON de todos os dados do dispositivo em um toque
- Limpeza total apaga o banco local de forma limpa

### Acabamento
- Modo escuro + claro com alternância em um toque
- Alternância de unidades métricas / imperiais
- Transições de página personalizadas (fade + slide)
- Navegação inferior suave que desliza entre abas
- Animações escalonadas de entrada no dashboard
- Anel de calorias com `TweenAnimationBuilder` + brilho radial + gradiente de texto com shader-mask

---

## Stack técnica

| Camada | Escolha |
|---|---|
| Framework | Flutter (Dart 3.x) |
| BD local | Isar 3 |
| Estado | Riverpod 2 |
| Auth e backup | Firebase Auth, Cloud Firestore |
| IA (alimentos, coach, rotina) | **Groq** (Llama 3.3 70B + Llama 4 Scout vision) — fallback para Gemini Flash |
| Consulta cruzada de nutrição | USDA FoodData Central |
| Gráficos | fl_chart |
| Notificações | flutter_local_notifications + timezone |
| Seleção de imagem | image_picker |
| Animações | flutter_animate + TweenAnimationBuilder + transições de página personalizadas |
| Tipografia | Plus Jakarta Sans (via `google_fonts`) |
| Logo + splash | flutter_launcher_icons + flutter_native_splash |

---

## Arquitetura

```
lib/
├── core/                      # Matemática de saúde, constantes
├── data/
│   ├── models/                # Coleções Isar + tipos embutidos
│   ├── repositories/          # Perfil, nutrição, medição, exercício, treino
│   ├── seed/                  # Biblioteca de exercícios embutida
│   └── db.dart                # Isar.open + schemas
├── services/
│   ├── ai/                    # Interface AiService + impls Gemini / Groq / Proxy
│   ├── auth/                  # Google / e-mail / anônimo + vinculação
│   ├── data/                  # Exportação JSON
│   ├── notifications/         # Wrapper do flutter_local_notifications
│   ├── nutrition/             # Cliente de consulta cruzada USDA
│   ├── progress/              # Metas adaptativas, sequência, badges
│   ├── settings/              # Configurações do app baseadas em SharedPreferences
│   ├── sync/                  # Camada de espelho Firestore
│   └── workout/               # Gerador de rotinas, rastreador de PRs, conselheiro de sobrecarga, cálculo de volume
├── features/
│   ├── account/               # Conta + visualização de privacidade
│   ├── auth/                  # Login + cadastro + pular como anônimo
│   ├── coach/                 # Chat + revisão semanal
│   ├── food/                  # Planilha de ações de refeição, sugestões, alimentos personalizados
│   ├── onboarding/            # Perfil em 5 etapas + cálculo de alvo
│   ├── progress/              # Gráficos, sequência, badges, fotos
│   ├── settings/              editor de perfil, lembretes, unidades, sync de saúde
│   └── workout/               # Construtor de rotinas, logger, PRs, guia de exercícios
├── home/                      # Dashboard + shell de navegação inferior
├── state/                     # Providers Riverpod
├── widgets/                   # Widgets compartilhados (PressScale, etc.)
├── theme.dart                 # AppPalette, AppText, construtor de transições de página
├── firebase_options.dart      # Gerado por `flutterfire configure`
└── main.dart                  # Init Firebase, Isar, AppSettings, notificações
```

### Regras de design principais

- **Uma interface `AiService`, três implementações** (Gemini, Groq, Proxy). O provider escolhe a que estiver configurada. Trocar providers é uma mudança de uma linha.
- **Repositórios offline-first.** UI → Riverpod → repositório → Isar. IA e USDA são fontes de *enriquecimento*, nunca bloqueios; o app funciona totalmente offline para tudo, exceto chamadas de IA ao vivo.
- **Piso calórico + limite de ritmo** aplicados dentro de `HealthMath.compute` — cada alvo mostrado ao usuário os respeita.
- **Schema de sincronização exclui explicitamente fotos de progresso e medições corporais** para que nunca saiam do dispositivo.

---

## Primeiros passos

### 1. Pré-requisitos
- Flutter 3.x (`flutter doctor` deve estar verde)
- Um projeto Firebase (tier gratuito) — para auth + backup na nuvem
- Uma chave de API Groq (gratuita, sem cartão) — para funcionalidades de IA

### 2. Clonar

```bash
git clone https://github.com/<seu-username>/fitevo.git
cd fitevo
flutter pub get
```

### 3. Configurar Firebase

```bash
npm install -g firebase-tools
dart pub global activate flutterfire_cli
firebase login
flutterfire configure
```

Habilite no console do Firebase:
- **Authentication** → E-mail/Senha, Google e Anônimo
- **Firestore Database** (em modo de produção)

Implante as regras de segurança do Firestore:

```bash
firebase deploy --only firestore:rules
```

### 4. Credenciais (`env.json`)

Copie o template versionado e preencha seus valores:

```bash
cp env.json.sample env.json
```

```json
{
  "AI_PROXY_URL": "https://fitevo-ai.SEU-SUBDOMINIO.workers.dev",
  "GROQ_API_KEY": "gsk_...",
  "GEMINI_API_KEY": "...fallback direto opcional...",
  "USDA_API_KEY": "...consulta cruzada opcional..."
}
```

O `env.json` é **ignorado pelo git — nunca o commite**. O `env.json.sample` é o
template versionado.

| Variável | Papel | Segurança |
|---|---|---|
| `AI_PROXY_URL` | Cloudflare Worker que guarda a chave de IA no servidor (recomendado para distribuição) | Embutida no binário, mas é apenas um endpoint — **não é segredo** |
| `GROQ_API_KEY` | Fallback direto via Groq | **Embutida no binário** — extraível do APK. Só para dev local; não distribua |
| `GEMINI_API_KEY` | Fallback direto via Gemini | **Embutida no binário** — extraível do APK. Só para dev local; não distribua |
| `USDA_API_KEY` | Consulta cruzada nutricional | Embutida no binário — use uma chave gratuita e de escopo mínimo |

> **Por que o proxy existe:** valores de `--dart-define-from-file` são compilados
> dentro do app. Distribuir uma chave Gemini/Groq real permite que qualquer um
> descompile o APK e consuma sua cota. Com o Worker, a chave real fica nos
> secrets do Cloudflare (lado do servidor) e o app carrega apenas a URL pública
> do Worker. Você mantém o controle: rotacione a chave, aplique rate-limit ou
> revogue o acesso a qualquer momento sem recompilar o app.

Obtenha chaves gratuitamente:
- **Groq**: [console.groq.com](https://console.groq.com) → API Keys
- **Gemini**: [aistudio.google.com](https://aistudio.google.com) → Obter chave de API
- **USDA**: [fdc.nal.usda.gov/api-key-signup](https://fdc.nal.usda.gov/api-key-signup)

### 5. Executar

```bash
flutter run --dart-define-from-file=env.json
```

Ou `.\run.ps1` — ele detecta o `env.json` automaticamente quando presente.
F5 no VS Code também funciona: `.vscode/launch.json` (ignorado pelo git) já
está pré-configurado para passar `env.json`.

### 6. Compilar para Android

```bash
flutter build apk --release --dart-define-from-file=env.json
```

Para uma build de **distribuição**, mantenha apenas `AI_PROXY_URL` no
`env.json`. Qualquer valor de `GROQ_API_KEY` / `GEMINI_API_KEY` presente no
momento do build é embutido no APK e pode ser extraído ao descompilá-lo. A
chave real do Worker nunca sai do servidor, então não vaza por esse caminho.

---

## Provedores de IA

O app é agnóstico de provedor: qualquer endpoint que fale o formato OpenAI
Chat Completions funciona (OpenAI, OpenRouter, DeepSeek, Mistral, xAI,
Together, Cerebras, Groq, Ollama, LM Studio, ...). No app, vá em
**Configurações → Chaves de API → Provedor de IA**, escolha um provedor/modelo
no catálogo [models.dev](https://models.dev) e cole sua própria chave.

Ordem de resolução (`lib/state/providers.dart`):

1. Provedor escolhido no app (chave do usuário) — catálogo models.dev
2. URL do proxy de IA no app (Cloudflare Worker)
3. Chaves Groq / Gemini no app
4. Defaults do build (`AI_PROXY_URL` → `GROQ_API_KEY` → `GEMINI_API_KEY`)

### Pacote de treinamento (proxy)

A personalidade e os prompts do treinador ficam no servidor, então todo
provedor mantém a mesma personalidade e contexto. Quando há URL de proxy
configurada, o app busca o pacote uma vez e o mantém em cache por 24 h:

```
GET {AI_PROXY_URL}/training

200 → {
  "version": 1,
  "prompts": {
    "coachPersona":    "...",
    "foodAnalysis":    "...",
    "routine":         "...",
    "mealSuggestions": "...",
    "targetsAdvisory": "...",
    "weeklyReview":    "...",
    "photoInstruction": "..."
  }
}
```

- Chaves ausentes mantêm os defaults embutidos (`lib/services/ai/ai_prompts.dart`).
- Não-200 ou offline → usa o pacote em cache (ou os defaults embutidos).
- O proxy é o único lugar para atualizar o conhecimento do treinador: publique
  um novo pacote no servidor e todo cliente/provedor o pega no próximo refresh.

---

## Fases do projeto

- **Fase 1** — Core: onboarding, dashboard, registro de IA em texto, BD local, logger de treinos básico ✅
- **Fase 2** — Expansão: registro por foto, construtor de rotinas, PRs, volume semanal, gráficos de progresso, lembretes, alimentos personalizados, sync manual com band, revisão semanal ✅
- **Fase 3** — Consolidação: serviço de IA proxy (esqueleto pronto), build web com fallbacks de plataforma, passada de acabamento completa ✅ *(em andamento)*

---

## Licença

[MIT](LICENSE) — faça o que quiser, atribuição é apreciada.

---

<div align="center">

Construído solo durante um café. Issues e PRs são bem-vindos.

</div>
