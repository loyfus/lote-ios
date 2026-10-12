# Loyfus — iOS

App iOS do Loyfus: **SwiftUI**, iOS 17+, sem dependências externas.
O projeto Xcode é gerado por [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de
`project.yml` — **`project.yml` é a fonte; o `.xcodeproj` é gerado e pode ser regenerado**.

Consome a API do repositório `loyfus-backend` (Spring Boot + PostgreSQL).

## Rodar

```bash
xcodegen generate
xcodebuild -project Loyfus.xcodeproj -target Loyfus \
  -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO

xcrun simctl install booted build/Debug-iphonesimulator/Loyfus.app
xcrun simctl launch booted br.com.loyfus
```

A base da API esta em `AppConfig.apiBaseURL` e o simulador alcanca a maquina em
`127.0.0.1:8080`. A API precisa estar no ar: suba o `loyfus-backend`.

## Testes

```bash
xcodebuild test -project Loyfus.xcodeproj -scheme Loyfus \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

Cobrem as mesmas regras do app Android — formatacao de preco, contagem regressiva e titulo de
lote — para nenhum dos dois clientes divergir do outro. O golden vector compartilhado esta em
`docs/design-v3/tidy_title.py`, no repositorio `loyfus-backend`.

## Deep link

`loyfus://lot/<id>` abre o lote, `loyfus://explore` abre a busca. Declarado no `Info.plist`.

## Documentacao

Fica no repositorio `loyfus-backend`, em `docs/`:

- `DESIGN_SYSTEM.md` — tokens, componentes, telas e o contrato de dados dos dois clientes
- `ARCHITECTURE.md` — como o app consome a API

## Estrutura

```
Loyfus/
├── Core/        formatacao de preco, titulo de lote, tema — espelhado no Android
├── Data/        cliente HTTP, repositorio e stores (favoritos, buscas recentes)
├── DesignSystem/ tokens, componentes e o glifo da marca
└── Features/    telas (home, explorar, lote, salvos, ajustes)

tools/ios_tap.py   clique por coordenada no simulador, para auditoria manual de UI
```
