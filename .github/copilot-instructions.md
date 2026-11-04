
# AgentGame2D — zasady projektu

## Technologia
- Godot 4.x
- GDScript
- Gra 2D typu top-down
- Bez C#, bez zewnętrznych frameworków

## Architektura
- Sceny zapisuj w res://scenes/
- Skrypty zapisuj w res://scripts/
- Grafiki zapisuj w res://assets/
- Dokumentację zapisuj w res://docs/
- Stosuj snake_case dla plików i funkcji.
- Stosuj PascalCase dla nazw klas.
- Preferuj sygnały zamiast silnych
  zależności między scenami.

## Zasady implementacji
- Zanim zmienisz plik, sprawdź jego zawartość.
- Nie nadpisuj działającego rozwiązania
  bez uzasadnienia.
- Jedno zadanie = jedna mała funkcjonalność.
- Nie dodawaj niepotrzebnych systemów.
- Nie instaluj dodatkowych zależności
  bez zatwierdzenia.
- Nie usuwaj plików bez zgody.

## Weryfikacja
- Po zmianie kodu sprawdź błędy składni.
- Jeśli dostępny jest Godot CLI,
  użyj go do walidacji projektu.
- Nie twierdź, że testy przeszły,
  jeśli nie zostały uruchomione.
- Podawaj zmodyfikowane pliki.

## Komunikacja
- Rozmawiaj z użytkownikiem po polsku.
- Wyjaśniaj nowe pojęcia Godot.
- Przy większych zmianach pokaż krótki plan.
- Zgłaszaj ryzyko i nieweryfikowane elementy.
