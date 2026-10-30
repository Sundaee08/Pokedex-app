# Pokédex – Communicating with Services (Flutter)

A simple black and white Flutter app that looks up a Pokémon by name using the public [PokéAPI](https://pokeapi.co/). It replaces the hard-coded JSON map from the previous lesson with live data from a remote service.

## Features

- Text field to enter a Pokémon name (press Enter or tap **Search**)
- Sends an HTTP `GET` request to `https://pokeapi.co/api/v2/pokemon/{name}`
- Displays name, ID, height, weight, types, abilities, stats, moves and sprite
- Loading indicator while waiting for a response
- Clear error messages instead of crashing or showing invalid data
- The Search button is disabled while a request is running, so repeated submissions cannot produce confusing results

## Running the project

```bash
flutter pub get
flutter run
```

The `http` package is required (`flutter pub add http`).

## Project structure

| Part | Purpose |
| --- | --- |
| `Pokemon` class | Data model. `Pokemon.fromJson()` converts the decoded JSON map into an object and validates the required fields. |
| `fetchPokemon()` | Sends the request, checks the status code, decodes the JSON and returns a `Pokemon`. |
| `ApiException` | Custom exception thrown when the server responds with a non-200 status code. |
| `_MyHomePageState.search()` | Calls `fetchPokemon()` and turns each kind of failure into a user-friendly message. |

## How the app handles communication

### Successful requests
The app sends a GET request. If the status code is `200`, the response body is decoded with `jsonDecode()` (from `dart:convert`), checked to be a JSON object, and converted into a `Pokemon` object. The UI then displays the object's fields.

### Unsuccessful HTTP responses
If the server responds with anything other than `200`, the body is **not** processed. An `ApiException` carrying the status code is thrown instead.

- `404` → "Pokemon not found. Check the spelling."
- Any other code (e.g. `500`) → "The server returned an error. Try again later."

### Network failures
If the device is offline, the server cannot be reached, or the request takes longer than 10 seconds, no HTTP response is received. The app catches this and shows "No connection" (or "The request took too long" for timeouts). This is handled separately from HTTP errors because retrying makes sense here, whereas retrying a `404` does not.

### Invalid data
A `200` response does not guarantee valid data. If the body is not valid JSON, is not a JSON object, or is missing required fields (`id`, `name`, `height`, `weight`), a `FormatException` is thrown and the app shows "The response could not be read" instead of displaying invalid values. Optional fields (stats, types, abilities, moves, sprite) are read defensively so missing values do not crash the app.

### Repeated submissions
While a request is in progress, the Search button is disabled and `search()` returns immediately if called again. This avoids overlapping requests whose results could arrive in the wrong order.

## Proposed offline strategy

The app currently needs a connection for every search. To make previously viewed Pokémon available offline, I would add local caching:

1. **Save on success.** Each time a request succeeds, convert the `Pokemon` to JSON (add a `toJson()` method) and store it locally, keyed by name, together with the time it was fetched. `shared_preferences` is enough for a few entries; a local database such as `sqflite`, Drift, or Hive would suit a larger history.
2. **Network first, cache as fallback.** When the user searches, try the API first. If it succeeds, show the fresh data and update the cache.
3. **Use the cache only for connection problems.** If the request fails because of a network error, timeout, or server error (`5xx`), look for the Pokémon in the cache. If it exists, display it. If it does not, show the normal error message. A `404` should not fall back to the cache, because it means the name is invalid.
4. **Be honest about freshness.** When showing cached data, display a notice such as "You're offline. Showing data saved on 30 Oct 2026" and a **Refresh** button to try the request again once the connection returns.

Pokémon data rarely changes, so slightly outdated information is low-risk here. For data such as account balances, showing old values as if they were current would be inappropriate, so the strategy would be different.

## Activity: expected result

1. **Request for `pikachu`:** the app retrieves the information and displays name, ID, height, weight, types, abilities, stats, moves and sprite.
2. **Request for `thispokemondoesnotexist`:** the API responds with a `404` status code. The app detects this before decoding anything and displays "Pokemon 'thispokemondoesnotexist' was not found. Check the spelling." No invalid data is shown and the app does not crash.

## Analysis

**1. What information did the application receive from the Pokémon API, and how was it different from the JSON map used in the previous lesson?**

The API returned a large JSON response about the requested Pokémon, including its ID, name, height, weight, sprites, types, abilities, stats, and moves. The map from the previous lesson was a small piece of data written directly in the program, so it only covered one Pokémon and only the fields I chose to include. The API data is live and can be requested for any Pokémon, but I do not control its structure, so the app has to validate what it receives.

**2. What role did the HTTP GET method play in retrieving the Pokémon's information?**

GET is the HTTP method for retrieving a representation of a resource. By sending a GET request to `https://pokeapi.co/api/v2/pokemon/pikachu`, the app asks the service to return the Pokémon identified by that URL without changing anything on the server.

**3. Why did the application need to decode the response body before accessing individual fields?**

The response body arrives as plain text (a `String`), not as a Dart object. You cannot use `body['name']` on a string. `jsonDecode()` converts the JSON text into a Dart `Map`, which allows the app to read individual values by key.

**4. What was different about the response when the requested Pokémon did not exist? Why should an application check the HTTP status code before processing the response?**

The server answered with status code `404 Not Found` instead of `200 OK`, and the body was not Pokémon data. The status code should be checked first because an HTTP request can complete successfully and still report a failure. If the app skipped the check and decoded the body anyway, it could crash on invalid JSON or display meaningless data. Checking the status code makes sure only acceptable responses are processed.

**5. If the request fails because the device has no internet connection, how should the application respond differently from when the server reports that a Pokémon does not exist?**

With no connection, the app never receives an HTTP response, so the problem is with communication, not with the request. The app should tell the user to check their connection and allow them to retry, or show saved data if available. When the server reports a `404`, the server was reached and the resource simply does not exist, so retrying the same request will not help. The app should tell the user to check the spelling of the name instead.

**6. What could the application do to remain useful if the user had previously viewed the Pokémon's information but was now offline?**

It could store each successfully retrieved Pokémon locally (for example with `shared_preferences` or a local database) along with the time it was saved. When a request fails due to a connection problem, the app would display the saved copy with a notice that the data may be outdated and a button to refresh once the connection returns.

