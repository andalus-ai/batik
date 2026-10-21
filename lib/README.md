# AgentUIKit 🤖→📱

A model-agnostic Flutter framework for **agent-driven UI generation** — similar in spirit to Google Gemini's GenUI SDK, but provider-independent and highly extensible.

---

## Overview

AgentUIKit lets any LLM (or rules-based agent) produce declarative UI trees in JSON that are instantly rendered as native Flutter widgets — with no code generation step, no platform channel, and no hard dependency on any specific AI provider.

```
User prompt
    │
    ▼
AgentAdapter (Anthropic / OpenAI / GenericREST / Mock)
    │ JSON envelope
    ▼
UINode tree (schema-validated, version-stamped)
    │
    ▼
UIComponentRegistry → Flutter Widgets
    │ events
    ▼
ActionDispatcher → ActionHandler (your app logic)
```

---

## Quick Start

### 1. Initialize

```dart
// main.dart
import 'package:agent_ui_kit/agent_ui_kit.dart';

void main() {
  AgentUIKit.initialize(); // registers built-in components + bootstraps schema
  runApp(MyApp());
}
```

### 2. Drop in the chat widget

```dart
AgentUIChat(
  adapter: AnthropicAdapter(
    apiKey: 'sk-ant-...',
    appContext: 'A project management app for software teams.',
  ),
  actionHandler: MyActionHandler(),
)
```

### 3. Or render a response directly

```dart
AgentUIRenderer(
  response: AgentUIResponse.fromJsonString(jsonFromYourAgent),
  actionHandler: MyActionHandler(),
)
```

---

## Architecture

### Schema (`lib/src/schema/ui_schema.dart`)

The JSON schema that every agent must produce. Versioned via `schemaVersion`.

**Envelope:**
```json
{
  "schemaVersion": "1.0.0",
  "root": <UINode>,
  "metadata": {},
  "sessionId": "optional",
  "turnId": "optional"
}
```

**Node anatomy:**
```json
{
  "type": "card",
  "id": "profile-card",
  "style": { "padding": { "all": 16 }, "borderRadius": 12 },
  "actions": { "onTap": { "type": "navigate", "payload": { "route": "/profile" } } },
  "condition": "isLoggedIn",
  "children": [...]
}
```

### Built-in node types

| Category | Types |
|---|---|
| Layout | `container` `row` `column` `stack` |
| Content | `text` `richText` `image` `icon` `markdown` |
| Interactive | `button` `iconButton` `textField` `switch` `slider` `dropdown` |
| Structural | `card` `list` `listItem` `grid` `form` |
| Scaffold/Nav | `scaffold` `appBar` `bottomNav` `fab` |
| Overlays | `dialog` `snackbar` |
| Decoration | `divider` `spacer` `badge` `chip` `avatar` `progressBar` |
| Rich/Plugin | `chart` `map` `webview` `custom` |

### Registering custom components

```dart
// Register a custom node type (schema side)
UINode._registry['rating'] = (j) => RatingNode.fromJson(j);

// Register its Flutter builder (renderer side)
UIComponentRegistry.instance.register<RatingNode>((ctx, node, renderer) {
  return StarRating(value: node.value, onChanged: (v) {
    ctx.agentDispatcher.dispatch(ctx, UIAction(
      type: ActionTypes.setVariable,
      payload: {'key': node.variableBinding ?? 'rating', 'value': v},
    ));
  });
});
```

Or use the `custom` node + `registerCustom`:

```dart
UIComponentRegistry.instance.registerCustom('video-player', (ctx, node, renderer) {
  return VideoPlayerWidget(url: node.props['url']);
});
```

### Adapters

Implement `AgentAdapter` for any backend:

```dart
class MyAdapter extends AgentAdapter {
  @override
  Future<AgentTurnOutput> sendTurn(AgentTurnInput input) async {
    final raw = await myLLM.complete(input.userMessage);
    return AgentTurnOutput(uiResponse: parseResponse(raw));
  }

  @override
  AgentUIResponse? parseResponse(dynamic raw) {
    // Extract JSON from LLM output
  }
}
```

Built-in adapters:
- **`AnthropicAdapter`** — Claude (any model via `/v1/messages`)
- **`OpenAIAdapter`** — GPT-4o with `response_format: json_object`
- **`GenericRestAdapter`** — any REST endpoint
- **`MockAdapter`** — offline dev & testing

### Actions

Declarative events that the renderer dispatches to your `ActionHandler`:

| Type | Payload | Description |
|---|---|---|
| `agentMessage` | `{message}` | Send a follow-up to the agent |
| `navigate` | `{route}` | App navigation |
| `setVariable` | `{key, value}` | Write to VariableStore (handled in-framework) |
| `openUrl` | `{url}` | Open external link |
| `dismiss` | — | Close current overlay |
| `submitForm` | `{formId}` | Submit form |
| `custom` | `{handler, ...}` | Your own action types |

### Variable Store & Conditions

Interactive components (`textField`, `switch`, `slider`, `dropdown`) bind to the `VariableStore` via `variableBinding`. Any node can conditionally show/hide via `condition`:

```json
{
  "type": "text",
  "text": "Admin panel",
  "condition": "isAdmin"
}
```

```dart
// At runtime:
context.agentVariables.set('isAdmin', true); // node appears
context.agentVariables.set('isAdmin', false); // node hides
```

---

## System Prompt

`UISystemPromptBuilder.build()` generates a detailed prompt instructing any LLM to produce valid AgentUIKit JSON. Inject this as the system prompt for your agent:

```dart
final systemPrompt = UISystemPromptBuilder.build(
  appContext: 'A fintech app for retail investors.',
  schemaVersion: '1.0.0',
  allowedComponents: ['card', 'text', 'button', 'list', 'chart'],
);
```

---

## Style Reference

```json
{
  "backgroundColor": "#RRGGBB | named",
  "foregroundColor": "#RRGGBB | named",
  "borderColor": "#RRGGBB",
  "borderRadius": 12,
  "borderWidth": 1,
  "padding": { "all": 16 },
  "margin": { "top": 8, "bottom": 8 },
  "width": 300,
  "height": 200,
  "opacity": 0.8,
  "elevation": 4,
  "fontSize": 16,
  "fontWeight": "bold | w500 | ...",
  "fontFamily": "Roboto",
  "letterSpacing": 0.5,
  "lineHeight": 1.5,
  "textAlign": "center | left | right | justify",
  "overflow": "ellipsis | clip | fade",
  "flex": 1,
  "alignment": "center | topLeft | bottomRight | ...",
  "shadow": { "color": "#000", "blurRadius": 8, "offsetX": 0, "offsetY": 2 },
  "gradient": { "type": "linear", "colors": ["#6750A4", "#B4A8D6"], "angle": 135 }
}
```

---

## Extending for Production

| Concern | Recommendation |
|---|---|
| Streaming responses | Implement `AgentAdapter.streamTurn()` + use `StreamBuilder` |
| Markdown rendering | Swap `MarkdownNode` builder to use `flutter_markdown` |
| Charts | Register `ChartNode` builder with `fl_chart` |
| Maps | Register `MapNode` builder with `google_maps_flutter` |
| WebView | Register `WebViewNode` builder with `webview_flutter` |
| Schema validation | Add JSON Schema validation layer before `fromJson` |
| Caching | Wrap adapter with a memoization layer |
| Analytics | Emit events in `ActionDispatcher.dispatch` |
| Theming | Pass `ThemeData` to `AgentUIRenderer` |
| A/B testing | Swap `UIComponentRegistry` instances per experiment |

---

## License

MIT
