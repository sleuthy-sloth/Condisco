# Early German/Portuguese feedback sample — 2026-09-30

Scope: six text-response tasks per language from the first four lessons. This is an AI-assisted editorial inspection and structural record, not native-speaker review. The automated audit verifies hint/error presence; it cannot establish naturalness or learner usefulness.

| Language | Activity | Prompt | Accepted forms | Error examples |
|---|---|---|---|---|
| german | `de-cafe-mission-act-7` | Say the order once in your head. Then write in German: A coffee, please. | Einen Kaffee, bitte. | 2 |
| german | `de-cafe-mission-act-9` | Write the three lines in order: Hello. / A coffee, please. / Thank you. | Hallo. Einen Kaffee, bitte. Danke. | 2 |
| german | `de-introductions-foundation-recall` | You meet a neighbour. Introduce yourself as Anna with the verb that means 'to be called'. | Ich heiße Anna. | 3 |
| german | `de-introductions-foundation-reply` | Your colleague has introduced himself. Recall the two-word reply practised here for “Nice to meet you”. | Freut mich. | 2 |
| german | `de-introductions-foundation-ask` | Ask a classmate their name with the three-word question practised here, beginning with Wie. | Wie heißt du? | 3 |
| german | `de-introductions-foundation-read` | Read the exchange. The first line puts the verb before the person to ask something. Whose name is being asked for? | Leo / Leo. | 2 |
| portuguese | `pt-cafe-mission-act-7` | Think the order once in your head. Then write in Portuguese: A coffee, please. | Um café, por favor. | 3 |
| portuguese | `pt-cafe-mission-act-9` | Write the three lines in order: Hello. / A coffee, please. / Thank you. | Olá. Um café, por favor. Obrigado. / Olá. Um café, por favor. Obrigada. | 2 |
| portuguese | `pt-introductions-foundation-ask` | Ask a neighbour's name using the full question taught here. | Qual é o seu nome? | 2 |
| portuguese | `pt-introductions-foundation-recall` | Give your name as Ana with the phrase 'my name is', keeping the accent on the word for 'is'. | O meu nome é Ana. | 2 |
| portuguese | `pt-introductions-foundation-read` | Read the exchange. One speaker introduces themselves with no word for 'I' at all. Who is it? | Leo / Leo. / Sou Leo. | 1 |
| portuguese | `pt-introductions-foundation-reply` | Recall the short Portuguese reply practised here for “Nice to meet you”. | Prazer. / Muito prazer. | 2 |

## Findings handled

- German introduction reply now explicitly recalls the taught two-word expression. Its correction no longer says other introduction replies are inherently wrong.
- German name question now explicitly requests the taught three-word question beginning with Wie, so a valid different question is not silently mistaken for a language error.
- Portuguese introduction reply now asks for a short reply rather than one word, matching its accepted Prazer / Muito prazer forms.
- Existing name/number/article corrections retain their specific grammatical contrast. No blanket expansion of accepted answers was performed.

## Still open

Language quality of the new listening and spoken-response material, voice naturalness, and whether the feedback is useful in practice need observations. Each new audio asset keeps reviewPending true. The owned-iPhone run sheet supplies the checks; the solo study kit supplies the delayed-practice protocol.
