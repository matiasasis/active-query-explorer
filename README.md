# Active Query Explorer

A mountable Rails engine that provides a web UI for browsing, searching, and executing [Active Query](https://github.com/matiasasis/active-query) objects registered in your application.

## Overview

Active Query Explorer discovers all classes registered in `ActiveQuery::Base.registry`, groups them by namespace, and presents them in an interactive interface. Developers can browse query definitions, inspect parameters (names, types, defaults, optionality), and execute queries directly from the browser.

It is designed for Rails applications that use the `active-query` gem to define query objects. If your app has query classes inheriting from `ActiveQuery::Base`, this engine makes them discoverable and runnable without writing any additional code.

## Installation

Add to your Gemfile. The gem is not yet published to RubyGems, so reference it via Git or a local path:

```ruby
# Via Git
gem "active-query-explorer", git: "https://github.com/matiasasis/active-query-explorer.git"

# Or via local path during development
gem "active-query-explorer", path: "../active-query-explorer"
```

Then run:

```bash
bundle install
```

**Requirements:** Ruby >= 3.2, Rails >= 6.1 and < 9.0, `active-query` >= 0.1.3.

## Mounting the Engine

Add to your `config/routes.rb`:

```ruby
mount ActiveQueryExplorer::Engine => "/queries", as: "active_query_explorer"
```

After starting your Rails server, visit `http://localhost:3000/queries` to access the UI.

The engine is isolated-namespaced (`ActiveQueryExplorer`), so it will not conflict with your application's routes or controllers.

## Usage

### Web UI

The HTML interface at your mount path provides:

- **Sidebar** -- Query classes grouped by namespace, with collapsible sections and count badges. Clicking a class scrolls to its detail card.
- **Search** -- Full-text filtering across class names, query names, descriptions, and parameter names. Focus with `Cmd+K` / `Ctrl+K`.
- **Filters** -- Namespace dropdown, parameter presence toggle (all / with params / without params).
- **Query cards** -- Expandable cards showing each query's description, parameters (name, type, required/optional, default value), and source file location.
- **Inline execution** -- Form fields rendered per-parameter with type labels. Submit to execute the query and see results with timing metadata.

### Example Flow

1. Visit `/queries`
2. Browse or search for a query (e.g., `Billing::InvoiceQuery#overdue`)
3. Expand the query card to see its parameters
4. Fill in parameter values and click Execute
5. View the returned result set inline

## API / Formats

The index endpoint supports three response formats:

### HTML (default)

```
GET /queries
```

The interactive UI described above.

### JSON

```
GET /queries.json
```

Returns the full query catalog as structured JSON -- an array of namespace groups, each containing query objects with their class names, source locations, and query definitions (name, description, parameters).

Useful for building custom tooling or dashboards.

### Text

```
GET /queries.text
```

Returns an AI-consumable plain text catalog. Each query is rendered as a structured block:

```
=== QUERY START ===
name: Billing::InvoiceQuery#overdue
namespace: Billing
description: Find overdue invoices
returns: unknown
side_effects: unknown
idempotent: unknown
safety: unknown

inputs:
  - name: days
    type: Integer
    required: true
    default: none
=== QUERY END ===
```

Useful for including query definitions in LLM context or generating documentation.

### Execute Endpoint

```
POST /queries/execute
Content-Type: application/json

{
  "query_class": "Billing::InvoiceQuery",
  "query_name": "overdue",
  "args": { "days": 30 }
}
```

Returns `{ "result": <serialized_data> }` on success, or `{ "error": "message" }` on failure. CSRF token is required (the UI handles this automatically).

## Configuration

Create an initializer (e.g., `config/initializers/active_query_explorer.rb`):

```ruby
ActiveQueryExplorer.result_limit = 200          # Max records returned (default: 100)
ActiveQueryExplorer.query_paths = %w[queries]    # Subdirectories under app/ to eager-load (default: ["queries", "query_objects"])
```

### Swappable Services

The discovery, execution, and serialization layers can be replaced:

```ruby
ActiveQueryExplorer.discovery_class = MyCustomDiscovery
ActiveQueryExplorer.executor_class = MyCustomExecutor
ActiveQueryExplorer.serializer_class = MyCustomSerializer
```

Each must implement the same interface as the default classes (see Architecture below).

## Architecture

```
lib/
  active_query_explorer.rb          # Module entry point, configuration accessors
  active_query_explorer/
    engine.rb                       # Rails engine definition, eager-loading initializer
    query_discovery.rb              # Reads ActiveQuery::Base.registry, groups by namespace
    query_executor.rb               # Coerces args, whitelists params, calls query methods
    result_serializer.rb            # Serializes AR relations, records, scalars, enumerables
    query_text_formatter.rb         # Generates plain text query catalog
    version.rb                      # VERSION = "0.1.0"

app/
  controllers/active_query_explorer/
    queries_controller.rb           # index (html/json/text) + execute (json)
  views/active_query_explorer/queries/
    index.html.erb                  # Full UI (HTML + CSS + JS, self-contained)

config/
  routes.rb                         # Engine routes
```

### Discovery Flow

1. On Rails boot, the engine's `eager_load_queries` initializer loads all Ruby files from `app/queries/`, `app/query_objects/`, and their Packwerk equivalents (`packs/*/app/queries/`, `packs/*/app/query_objects/`).
2. When the index action is hit, `QueryDiscovery#grouped_queries` reads `ActiveQuery::Base.registry`, filters to Class entries, extracts each class's `.queries` definitions, and groups them by namespace (derived from the class name).
3. Each query definition includes its name, description, and parameter definitions (`args_def`).

### Execution Flow

1. Controller validates `query_class` and `query_name` against `VALID_QUERY_NAME` regex (`/\A[a-zA-Z_]\w*\z/`).
2. `QueryDiscovery` resolves the class and query definition.
3. `QueryExecutor` whitelists arguments against `args_def` keys, coerces types via `ActiveQuery::TypeRegistry.coerce`, and calls the query method via `public_send`.
4. `ResultSerializer` converts the result (AR relation, record, scalar, or enumerable) to JSON-safe output, applying `result_limit`.

## Adding Query Objects

Query objects are discovered automatically. To add a new one:

1. Create a class that inherits from `ActiveQuery::Base` in `app/queries/` (or `app/query_objects/`):

```ruby
# app/queries/billing/invoice_query.rb
class Billing::InvoiceQuery < ActiveQuery::Base
  query :overdue,
        description: "Find invoices past due date",
        args_def: {
          days: { type: Integer, optional: false },
          status: { type: String, optional: true, default: "pending" }
        }

  def self.overdue(args = {})
    Invoice.where("due_date < ?", args[:days].days.ago)
            .where(status: args[:status])
  end
end
```

2. The class registers itself in `ActiveQuery::Base.registry` (handled by the `active-query` gem).
3. Restart your Rails server (or, in development, the class will be loaded on the next request if eager loading is configured).
4. Visit the explorer UI -- your query appears grouped under its namespace.

**Packwerk support:** If your app uses Packwerk, place query objects in `packs/<pack_name>/app/queries/` and they will be discovered automatically.

## Development

### Setup

```bash
git clone <repo-url>
cd active-query-explorer
bundle install
```

### Running Tests

```bash
bundle exec rspec
```

Tests use an in-memory SQLite database. The test suite covers configuration, discovery, execution, serialization, the controller (including input validation and error handling), and the text formatter.

CI runs on Ruby 3.2, 3.3, and 3.4 via GitHub Actions.

## Known Gaps

- **Authentication/authorization:** The engine does not include any access control. You must restrict access yourself (e.g., via a routing constraint or middleware). Since the execute endpoint runs arbitrary registered queries, this is important in production.
- **Not published to RubyGems:** Must be referenced via Git or path in your Gemfile.
- **Query interface assumptions:** The engine assumes query classes respond to `.queries` returning an array with `:name`, `:description`, and `:args_def` keys. This is dictated by the `active-query` gem's API -- refer to its documentation for the definitive contract.
- **Text format metadata:** The `returns`, `side_effects`, `idempotent`, and `safety` fields in the text format are always `unknown` -- the `active-query` gem does not currently expose this metadata.
- **Result limit is global:** `result_limit` applies to all queries uniformly; there is no per-query override.

## License

MIT License. See [LICENSE](LICENSE) for details.
