# Comprehension-prompt worklist — 2026-09-26

Slice 2.2 step 1 (analysis only, no pack edits). Source seed: strict audit run
`audit-strict-2.2-prep.txt` — the 102 `reason=comprehension` open-ended graded text
activities (informational exit-gate rows). The audit report caps each pack's list at
20 lines, so 11 rows were hidden under "… and N more"; the full 102 were re-enumerated
from `Condisco/Content/packs/<language>.json` using the audit's own classification
heuristics and cross-checked against the audit's per-pack counts
(french 13, italian 18, german 21, portuguese 29, spanish 21 → 102 ✓).

Dispositions: **clear** · **narrow wording** · **add variants** · **convert to selection/self-compare**.
Rows marked non-`clear` name a concrete, genuinely valid answer the fixed list rejects.

## Method note (how each row was judged)

For every prompt the matching top-level activity in `Condisco/Content/packs/<language>.json`
was read directly (`kind: text`, matched by activity id): the `prompt`, the `answer.answers`
list, the authored `errors`, the hint (which quotes the dictated passage sentence), and,
where needed, the `stimulusId` passage `body`/`translation`.

Judgment rules, fixed in advance to stay conservative:

1. **Exactly what the grader rejects** — read from `Condisco/Engine/AnswerEngine.swift`:
   input is lowercased and punctuation-stripped, so case and trailing punctuation never
   matter; missing accents are forgiven on words ≥ 4 letters (so `caffè`→`caffe`,
   `perché`→`perche`, `naechste Woche` pass automatically); **digits are not forgiven**
   (`le 3 mai` ≠ `le trois mai`); **word order is not forgiven**; **missing/extra words
   are not forgiven** (a full sentence is not a subsequence pass for a phrase answer). A
   rejection named below is a rejection under these real rules.
2. **`clear`** when the accepted list covers the dictated passage phrase in the natural
   form(s) a learner produces — target-language phrase, bare form and/or English form as
   authored — and every rejection is of a wrong/partial/distractor item the error list
   explicitly explains. Rejecting incomplete-but-true *partials* of the dictated phrase
   (`A window.` for `a big window`) is treated as pedagogical precision, not a defect.
3. **`add variants`** — the question and the dictated answer are fine, but a standard
   surface form of the same answer is missing from the list: digit dates/times/numbers
   (`le 3 mai`, `il 3 maggio`), bare time/number words (`dix heures`, `Deux.`/`Two.`).
   These are exactly the forms sibling packs accept (`de-months-foundation-read` accepts
   `3. Mai`; `es-months-foundation-read` accepts both `el 5 de enero` and `el cinco de
   enero`; `pt-a2-conjuntivo-intro-read` accepts `At 10.`; `es-numbers-quantities-foundation-read`
   accepts `3 euros`).
4. **`narrow wording`** — the question is broader than the grader: a complete, natural
   answer is rejected even though the twin activity in another pack accepts it, or the
   passage's own wording is rejected, or a whole answer language is missing.
5. Accents that distinguish words are preserved as requirements (`tè` vs `te`, `è` vs
   `e`, `sí` vs `si`, `café` — the engine already handles these correctly).
6. `convert to selection/self-compare` — reserved for prompts whose answer space a fixed
   list cannot cover at all. Found **0** such rows: every flagged prompt has a dictated
   passage answer; the issues are coverage of that answer's valid forms, not openness.

Notable verification: the 11 hidden rows were identified by re-enumerating every
comprehension-classified top-level activity per pack (prompt heuristic + `-read`-suffix
+ recall patterns, excluding `selection`-kind recall activities which the audit skips);
per-pack counts match the audit exactly.

---

## Worklist

### french (13)

| lesson / step | question | acc | disposition | note |
|---|---|---|---|---|
| fr-identity-foundation / fr-identity-foundation-step-fr-identity-foundation-read | What is her name? (Reading 1) | 2 | clear | Answers `Anna`, `Her name is Anna.` |
| fr-people-foundation / fr-people-foundation-step-fr-people-foundation-read | Who is French? (Reading 2) | 2 | clear | Answers `Anna`, `Anna is French.` |
| fr-family-foundation / fr-family-foundation-step-fr-family-foundation-read | Does Anna have a brother? Answer in English. (Reading 3) | 3 | clear | `yes`, `Yes, she does.`, `She has a brother.` |
| fr-numbers-foundation / fr-numbers-foundation-step-fr-numbers-foundation-read | How old is the sister? Answer with the French number. (Reading 4) | 2 | clear | `trente`, `trente ans`; number word dictated, digits legitimately excluded |
| fr-days-foundation / fr-days-foundation-step-rb7 | When is Anna's birthday? Answer with the French date. (Reading 17) | 1 | add variants | Only `le trois mai` accepted; standard written date `le 3 mai` (digit) rejected — error list only teaches the word form. Sibling packs accept digit dates (`de-months` `3. Mai`, `es-months` `el 5 de enero`) |
| fr-time-foundation / fr-time-foundation-step-rb7 | When does the train leave? Answer in French. (Reading 18) | 3 | clear | `à huit heures et demie`, bare `huit heures et demie`, full sentence |
| fr-cafe-order-foundation / fr-cafe-order-foundation-step-fr-cafe-order-foundation-read | How much does the coffee cost? Answer with the French number. (Reading 24) | 2 | clear | `trois`, `trois euros`; number word dictated |
| fr-a2-passe-compose-formation / fr-a2-passe-compose-formation-step-fr-a2-passe-compose-formation-read | What did they have at the restaurant ? (Reading) | 6 | clear | FR+EN full phrase, both cases, plus `The set menu` |
| fr-a2-passe-imparfait-choix / fr-a2-passe-imparfait-choix-step-fr-a2-passe-imparfait-choix-read | Who wanted to see him ? (Reading) | 3 | clear | `Le médecin` / `The doctor` |
| fr-a2-futur-formation / fr-a2-futur-formation-step-fr-a2-futur-formation-read | When will the meeting start ? (Reading) | 3 | add variants | Only `À dix heures` / `At ten.`; bare time `dix heures` (no `à`) rejected (missing word). The parallel foundation time prompt fr-time-foundation-read accepts the bare form |
| fr-a2-conditionnel-politesse / fr-a2-conditionnel-politesse-step-fr-a2-conditionnel-politesse-read | How many nights ? (Reading) | 3 | add variants | Only `Deux nuits` / `Two nights.`; natural short answers `Deux.` / `Two.` rejected (missing word) |
| fr-a2-relatifs-qui-que-ou / fr-a2-relatifs-qui-que-ou-step-fr-a2-relatifs-qui-que-ou-read | What is in the office ? (Reading) | 3 | clear | `Une grande fenêtre` / `A big window.`; partial `Une fenêtre` rejected deliberately (full dictated phrase) |
| fr-a2-superlatifs / fr-a2-superlatifs-step-fr-a2-superlatifs-read | What does the Louvre have ? (Reading) | 3 | clear | `La plus belle collection` / `The most beautiful collection.` |

### italian (18)

| lesson / step | question | acc | disposition | note |
|---|---|---|---|---|
| it-identity-foundation / it-identity-foundation-step-it-identity-foundation-read | What is her name? (Reading 1) | 1 | narrow wording | Only `Anna` accepted (allowTypo=false); complete answer `Her name is Anna.` rejected. The FR twin fr-identity-foundation-read accepts both |
| it-people-foundation / it-people-foundation-step-it-people-foundation-read | Who is Italian? (Reading 2) | 1 | narrow wording | Only `Anna` accepted; `Anna is Italian.` rejected (the FR twin accepts `Anna is French.`) |
| it-family-foundation / it-family-foundation-step-it-family-foundation-read | What is the brother's name? (Reading 3) | 1 | narrow wording | Only `Marco` accepted; `His name is Marco.` rejected |
| it-numbers-foundation / it-numbers-foundation-step-rb7 | How old is the sister? Answer with the Italian number. (Reading 4) | 1 | clear | `trenta`; number word dictated |
| it-descriptions-foundation / it-descriptions-foundation-step-rb7 | Which thing is big? Answer in Italian. (Reading 6) | 1 | clear | `la casa` is the passage's exact phrase for the big thing |
| it-plural-foundation / it-plural-foundation-step-rb6 | What color are the books? Answer in Italian. (Reading 7) | 1 | clear | `bianchi`, the taught color word |
| it-negation-foundation / it-negation-foundation-step-rb8 | Does the speaker work at home? Answer in English. (Reading 9) | 3 | narrow wording | List: `no`, `No, he doesn't.`, `He doesn't work at home.` — passage (`Non lavoro in casa`) states no gender, yet only he-forms pass; `No, she doesn't.` / `She doesn't work at home.` / first-person `No, I don't.` are equally valid and rejected |
| it-food-foundation / it-food-foundation-step-it-food-foundation-read | What does the other person order? Answer in Italian. | 1 | clear | `un tè`; `tè` rejected deliberately (article required, hint dictates it); accent on tè distinguishes the word |
| it-possession-foundation / it-possession-foundation-step-rb7 | What is small? Answer in Italian. (Reading 11) | 1 | narrow wording | Only truncated `il libro` accepted; the passage's own phrase `Il mio libro è piccolo` → answering `il mio libro` is rejected as "extra word". The exact dictated noun phrase is not in the list |
| it-requests-foundation / it-requests-foundation-step-it-requests-foundation-read | What does the speaker want? Answer in Italian. (Reading 13) | 2 | clear | `un caffè`, `caffè` (article optional) |
| it-past-foundation / it-past-foundation-step-rb5 | Where did the speaker study? Answer in Italian. (Reading 15) | 1 | clear | `in casa`, the direct where-phrase |
| it-plans-foundation / it-plans-foundation-step-rb6 | When is the speaker going to Rome? Answer in Italian. (Reading 16) | 1 | clear | `domani`, the taught time word |
| it-days-foundation / it-days-foundation-step-rb7 | When is Anna's birthday? Answer with the Italian date. (Reading 17) | 1 | add variants | Only `il tre maggio`; standard written date `il 3 maggio` (digit) rejected. Sibling packs accept digit dates |
| it-market-foundation / it-market-foundation-step-it-market-foundation-read | How much is the bread? Answer with the Italian price. (Reading 20) | 1 | clear | `un euro`; price phrase dictated |
| it-emergency-foundation / it-emergency-foundation-step-rb5 | What number? Answer with the Italian number name. (Reading 23) | 1 | clear | `il centododici`; number name + article dictated by hint |
| it-cafe-order-foundation / it-cafe-order-foundation-step-it-cafe-order-foundation-read | What does the customer order? Answer in Italian. (Reading 24) | 2 | clear | `un caffè`, `caffè` |
| it-a2-congiuntivo / it-a2-congiuntivo-step-rb8 | Secondo il testo, qual è la cosa più difficile? (What is the hardest thing?) | 2 | clear | `Il congiuntivo.` + full sentence |
| it-a2-comparativi / it-a2-comparativi-step-rb8 | Secondo il testo, perché ha scelto il secondo computer? (Why the second one?) | 2 | narrow wording | Two authored phrasings only; the passage's own wording `Perché è migliore per il mio lavoro.` (per the hint "per il mio lavoro è migliore, perché viaggio molto") is rejected — an open "why" question whose valid restatements a 2-item list cannot cover |

### german (21)

| lesson / step | question | acc | disposition | note |
|---|---|---|---|---|
| de-introductions-foundation / de-introductions-foundation-step-de-introductions-foundation-read | Read the exchange. … Whose name is being asked for? | 2 | clear | `Leo` (both list entries normalize identically) |
| de-cafe-requests-foundation / de-cafe-requests-foundation-step-de-cafe-requests-foundation-read | Read the café exchange. Which word marks the drink…? | 1 | clear | `einen`, dictated single word |
| de-time-days-foundation / de-time-days-foundation-step-de-time-days-foundation-read | Read the week. Which day does the passage place in the middle? | 2 | clear | `Mittwoch` / `Wednesday` (this was one of the 11 rows hidden under the audit's 20-line cap) |
| de-family-people-foundation / de-family-people-foundation-step-rb8 | …Which city have the parents stayed in? | 3 | clear | `Berlin` (+ `In Berlin.`) |
| de-home-foundation / de-home-foundation-step-de-home-foundation-read | …Which room is new? | 3 | clear | `Die Küche.` / `die Küche` / `Küche` |
| de-descriptions-foundation / de-descriptions-foundation-step-de-descriptions-foundation-read | …Which room is new and very big? | 3 | clear | same 3 kitchen forms |
| de-routine-foundation / de-routine-foundation-step-de-routine-foundation-read | Read the day plan. When does the writer eat? | 3 | clear | `Mittags.` case variants |
| de-questions-foundation / de-questions-foundation-step-rb8 | Read the chat. Where does Anna live? | 3 | clear | `In Berlin.` / `Berlin`; full sentence deliberately rejected as extra word |
| de-food-foundation / de-food-foundation-step-de-food-foundation-read | …What does the writer drink in the morning? | 3 | clear | `Wasser.` case variants |
| de-possession-foundation / de-possession-foundation-step-de-possession-foundation-read | …Whose bag is small? | 3 | clear | `meine Schwester` / `die Schwester` |
| de-plans-foundation / de-plans-foundation-step-de-plans-foundation-read | Read the plan. When does the writer visit the parents? | 3 | clear | `Nächste Woche` incl. umlaut-stripped `naechste Woche` |
| de-months-foundation / de-months-foundation-step-de-months-foundation-read | Read the note. When is the writer's birthday? | 3 | clear | `Am 3. Mai.` incl. digit date |
| de-health-foundation / de-health-foundation-step-rb8 | Read the note. Where does the writer go? | 3 | clear | `Zum Arzt.` / `Arzt` |
| de-invitations-foundation / de-invitations-foundation-step-rb8 | Read the invitation. When is the party? | 3 | clear | `Am Samstag.` / `Samstag` |
| de-a2-konjunktiv-wuerde / de-a2-konjunktiv-wuerde-step-de-a2-konjunktiv-wuerde-read | …Where would the speaker like to live? | 2 | clear | `In Italien.` / `Italien` |
| de-a2-hoefliche-bitten / de-a2-hoefliche-bitten-step-rb8 | …What does the guest ask for last? | 3 | clear | 3 phrasings of the window request |
| de-a2-komparativ / de-a2-komparativ-step-de-a2-komparativ-read | Read the comparison. What is cheaper than in town? | 3 | clear | `Das Frühstück.` incl. bare form |
| de-a2-wechselpraepositionen / de-a2-wechselpraepositionen-step-de-a2-wechselpraepositionen-read | Read the move. Where does the picture hang? | 2 | clear | `Über dem Sofa.` case variants |
| de-a2-passiv-intro / de-a2-passiv-intro-step-de-a2-passiv-intro-read | …What happens to the products here? | 2 | clear | full sentence + bare `gebaut und verkauft` |
| de-a2-berufsvokabular / de-a2-berufsvokabular-step-de-a2-berufsvokabular-read | Read the job ad. What should you send? | 3 | clear | `Den Lebenslauf.` / bare / `Ihren Lebenslauf.` |
| de-remember-recall / de-remember-recall-step-4 | You learned this in «First words»: how do you say thank you? | 1 | clear | `danke`, recalled single taught word |

### portuguese (29)

| lesson / step | question | acc | disposition | note |
|---|---|---|---|---|
| pt-introductions-foundation / pt-introductions-foundation-step-pt-introductions-foundation-read | …One speaker introduces themselves with no word for 'I' at all. Who is it? | 3 | clear | `Leo` + `Sou Leo.` |
| pt-cafe-requests-foundation / pt-cafe-requests-foundation-step-pt-cafe-requests-foundation-read | …Which form of thanks tells you the customer is a woman? | 1 | clear | `Obrigada.`, dictated single word |
| pt-directions-foundation / pt-directions-foundation-step-rb8 | Read the exchange and find the first direction the visitor is given. | 2 | narrow wording | Only English `Straight ahead.` accepted; the passage's own Portuguese direction `em frente` rejected (errors quote "em frente − straight ahead"). Accepted list has no Portuguese form |
| pt-time-days-foundation / pt-time-days-foundation-step-pt-time-days-foundation-read | …which day opens the week? | 2 | clear | `domingo` / `Sunday` (hidden row: 1 of the 9 under the cap) |
| pt-family-people-foundation / pt-family-people-foundation-step-rb8 | Read the family note. In which city did the parents stay? | 4 | clear | `Lisbon` / `Lisboa` / `In Lisbon.` |
| pt-home-foundation / pt-home-foundation-step-pt-home-foundation-read | Read the house note. Where does the cat sleep? | 4 | narrow wording | English-only list (`In the living room.` etc.); Portuguese `na sala` rejected though errors quote "o meu gato dorme na sala" (hidden row) |
| pt-descriptions-foundation / pt-descriptions-foundation-step-pt-descriptions-foundation-read | Read the house note. Which room is new? | 3 | narrow wording | English-only (`The bedroom.` etc.); Portuguese `o meu quarto` / `o quarto` rejected though errors quote "o meu quarto é novo" (hidden row) |
| pt-plural-foundation / pt-plural-foundation-step-pt-plural-foundation-read | Read the bakery note. How many bread rolls does the writer buy? | 5 | narrow wording | English/digit only (`Two.`, `2`, `He buys two.`); Portuguese `dois` / `dois pães` rejected though errors quote "compro dois pães". Every other pack accepts the number word (hidden row) |
| pt-negation-foundation / pt-negation-foundation-step-pt-negation-foundation-read | Read the coffee note. What do they drink at home instead of coffee? | 4 | narrow wording | English-only (`Tea.`, `Only tea.` …); Portuguese `chá` / `só chá` rejected though errors quote "só chá" (hidden row) |
| pt-food-foundation / pt-food-foundation-step-rb8 | Read the food note. What fruit does the writer eat every day? | 3 | narrow wording | English-only (`An apple.` …); Portuguese `uma maçã` / `maçã` rejected though errors quote "uma maçã todos os dias" |
| pt-possession-foundation / pt-possession-foundation-step-pt-possession-foundation-read | Read the car note. Where are the keys? | 4 | narrow wording | English-only (`In the bag.` …); Portuguese `na mala` rejected though errors quote "estão na mala" (hidden row) |
| pt-requests-foundation / pt-requests-foundation-step-rb8 | Read the restaurant exchange. What does the customer ask for first? | 3 | narrow wording | English-only (`To book a table for two.` …); Portuguese `reservar uma mesa` / `uma mesa para dois` rejected though errors quote "Gostaria de reservar uma mesa para dois" (hidden row) |
| pt-weather-foundation / pt-weather-foundation-step-pt-weather-foundation-read | Read the weather note. What is tomorrow going to be like? | 4 | narrow wording | English-only (`Cloudy and rainy.` …); Portuguese `nublado` / `vai estar nublado` rejected though errors quote "vai estar nublado e vai chover" (hidden row) |
| pt-time-telling-foundation / pt-time-telling-foundation-step-pt-time-telling-foundation-read | Read the station note. When does the train leave? | 4 | clear | `At four.` + `Às quatro.` — bilingual list (hidden row) |
| pt-months-foundation / pt-months-foundation-step-pt-months-foundation-read | Read the birthday note. When is the party? | 4 | narrow wording | English-only (`On June 15th.` …); Portuguese `em 15 de junho` / `15 de junho` rejected though errors quote "em 15 de junho" (hidden row) |
| pt-free-time-foundation / pt-free-time-foundation-step-rb8 | Read the weekend note. What does the writer's brother like to do? | 3 | narrow wording | English-only (`To cook.` …); Portuguese `cozinhar` rejected though errors quote "meu irmão gosta de cozinhar" |
| pt-health-foundation / pt-health-foundation-step-rb8 | Read the sick note. When is the writer going to the doctor? | 3 | clear | `Tomorrow morning.` + `Amanhã de manhã.` — bilingual |
| pt-pharmacy-foundation / pt-pharmacy-foundation-step-rb8 | Read the pharmacy note. What does the pharmacist ask for? | 4 | clear | `A prescription.` + `Receita.` / `A receita.` — bilingual (hidden row) |
| pt-invitations-foundation / pt-invitations-foundation-step-rb8 | Read the invitation. When is the dinner? | 4 | clear | `Saturday at eight.` + `Sábado às oito.` — bilingual |
| pt-look-back-recall / pt-look-back-recall-step-10 | From «First words»: a woman thanks you. Which form of thanks did you hear? | 1 | clear | `Obrigada.`, recalled single word |
| pt-a2-preterito-perfeito / pt-a2-preterito-perfeito-step-rb8 | Read about yesterday. What did the writer do in the afternoon? | 4 | clear | EN full + PT full + bare EN |
| pt-a2-imperfeito / pt-a2-imperfeito-step-read | Read about Tiago's childhood. How did he get to school? | 4 | clear | `He walked…` / `On foot.` / `A pé.` / `Ia a pé.` |
| pt-a2-futuro-simples / pt-a2-futuro-simples-step-rb8 | Read João's promises. What will he do in the afternoon? | 4 | clear | EN + PT (`Estudará…`, `Vai estudar…`) |
| pt-a2-condicional / pt-a2-condicional-step-rb8 | Read Rui's request. What does he offer in return? | 3 | clear | EN + `Ajudar com as compras.` |
| pt-a2-gostaria-queria / pt-a2-gostaria-queria-step-rb8 | Read Mr Silva's restaurant visit. What did he ask for first? | 2 | clear | `A table for two.` + `Uma mesa para dois.` |
| pt-a2-conjuntivo-intro / pt-a2-conjuntivo-intro-step-read | Read the mother's instructions. What time must he be home? | 5 | clear | `At ten.` / `By ten.` / `At 10.` / `Às dez.` + full sentence |
| pt-a2-comparativos / pt-a2-comparativos-step-read | Read the café debate. Why does Ana prefer the Central? | 3 | clear | EN full + `É mais barato e o atendimento é melhor.` |
| pt-a2-pronomes-preposicoes / pt-a2-pronomes-preposicoes-step-rb8 | Read Joana's invitation. How many tickets does she have? | 4 | clear | `Two.` / `Dois.` / `Dois bilhetes.` |
| pt-a2-superlativos-trabalho / pt-a2-superlativos-trabalho-step-read | Read about Sofia's new job. What time was the first meeting? | 4 | clear | `At nine.` / `At 9.` / `Às nove.` + full sentence |

### spanish (21)

| lesson / step | question | acc | disposition | note |
|---|---|---|---|---|
| es-introductions-foundation / es-introductions-foundation-step-es-introductions-foundation-read | …Which short word tells you the first speaker is talking about herself? | 1 | clear | `me`, dictated single word |
| es-cafe-requests-foundation / es-cafe-requests-foundation-step-es-cafe-requests-foundation-read | Read the café exchange. How many drinks does the customer order? | 3 | clear | `Two.` / `2.` / `Dos.` |
| es-time-days-foundation / es-time-days-foundation-step-es-time-days-foundation-read | Read the week. Which day does the passage name after the moon? | 2 | clear | `lunes` / `Monday` (hidden row: the 1 under the cap) |
| es-numbers-quantities-foundation / es-numbers-quantities-foundation-step-es-numbers-quantities-foundation-read | Read the price board. How much is the tea? | 3 | clear | `Three euros.` / `Tres euros.` / `3 euros.` incl. digit |
| es-family-people-foundation / es-family-people-foundation-step-rb7 | …Which city are the parents still in? | 3 | clear | `Madrid.` / `In Madrid.` |
| es-descriptions-foundation / es-descriptions-foundation-step-es-descriptions-foundation-read | Read the description. Which adjective describes the lamp? | 2 | clear | `Alta.` / `Tall.` |
| es-questions-foundation / es-questions-foundation-step-rb8 | Read the note. Where is the party? | 3 | clear | `En mi casa.` / `En casa.` / `At my house.` |
| es-requests-foundation / es-requests-foundation-step-rb8 | Read the café exchange. What does Ana order? | 3 | clear | `Un café.` / `A coffee.` / `Quiere un café.` |
| es-past-foundation / es-past-foundation-step-es-past-foundation-read | Read about yesterday. Who did the writer speak with? | 3 | clear | `Con Ana.` / `Ana.` / `With Ana.` |
| es-months-foundation / es-months-foundation-step-es-months-foundation-read | Read the birthday note. When is the writer's birthday? | 3 | clear | `El 5 de enero.` / `El cinco de enero.` / `January 5th.` — digit AND word forms |
| es-emergency-foundation / es-emergency-foundation-step-es-emergency-foundation-read | Read the emergency. What does the woman call? | 3 | clear | `Una ambulancia.` / `An ambulance.` + full line |
| es-invitations-foundation / es-invitations-foundation-step-rb8 | Read the invitation. Does Pablo accept? | 3 | clear | `Sí.` / `Yes.` / `¡Claro que sí!` |
| es-a2-preterito-formacion / es-a2-preterito-formacion-step-es-a2-preterito-formacion-read | Read the day. What time did the narrator get home? | 3 | clear | `A las once.` / `A las 11` / `las once` incl. digit |
| es-a2-futuro-formacion / es-a2-futuro-formacion-step-es-a2-futuro-formacion-read | Read the week ahead. When will the narrator travel to Barcelona? | 3 | clear | `El martes.` / `On Tuesday.` / `martes` (bare form) |
| es-a2-planes-intenciones / es-a2-planes-intenciones-step-es-a2-planes-intenciones-read | Read the life plan. Who is going to live with the narrator? | 4 | clear | `Su hermana.` / `Mi hermana.` / `la hermana` / `Her sister.` |
| es-a2-condicional / es-a2-condicional-step-rb8 | Read the dream trip. Where would the narrator go in spring? | 3 | clear | `A Japón.` / `To Japan.` / `Japón` |
| es-a2-subjuntivo-intro / es-a2-subjuntivo-intro-step-es-a2-subjuntivo-intro-read | Read the mother's rules. How many hours of sleep does she want? | 3 | clear | `Ocho horas.` / `ocho` / `Eight hours.` |
| es-a2-comparativos / es-a2-comparativos-step-es-a2-comparativos-read | Read the brothers. Who cooks better? | 4 | clear | `Yo.` / `El narrador.` / `I do.` |
| es-a2-por-para / es-a2-por-para-step-es-a2-por-para-read | Read the trip. When does the narrator return? | 3 | clear | `El lunes por la noche.` / `Monday night.` / `el lunes` |
| es-a2-superlativos / es-a2-superlativos-step-es-a2-superlativos-read | Read the new job. How many days a week does the narrator work? | 3 | clear | `Cuatro días.` / `cuatro` / `Four days.` |
| es-a2-tecnologia / es-a2-tecnologia-step-es-a2-tecnologia-read | Read the phone saga. What did the technician say was fine? | 3 | clear | `La batería.` / `batería` / `The battery.` |

---

## Summary

**Rows: 102** (french 13, italian 18, german 21, portuguese 29, spanish 21).

| disposition | count |
|---|---|
| clear | **81** |
| narrow wording | **17** |
| add variants | **4** |
| convert to selection/self-compare | **0** |

Per language: french 10 clear / 3 add variants · italian 11 clear / 6 narrow wording /
1 add variants · german 21 clear · portuguese 18 clear / 11 narrow wording ·
spanish 21 clear.

Most significant clusters:

- **Portuguese foundation reads (11 rows):** the graded `answers` lists are English-only
  while the question asks about a Portuguese passage; every Portuguese answer — including
  the passage's own phrases (`em frente`, `na sala`, `o meu quarto`, `dois pães`, `só
  chá`, `uma maçã`, `na mala`, `uma mesa para dois`, `vai estar nublado`, `15 de junho`,
  `cozinhar`) — is rejected as "incorrect". Sibling authors in the same pack
  (`pt-time-telling`, `pt-health`, `pt-pharmacy`, `pt-family-people`) accept both
  languages, so this reads as an authoring inconsistency, not a policy.
- **Italian single-word lists (4 rows):** `it-identity`, `it-people`, `it-family` accept
  only the bare name and reject complete English answers that the French twins accept;
  `it-possession` rejects the passage's own phrase (`il mio libro`).
- **Digit forms (fr/it days + bare forms in fr A2):** `le 3 mai` / `il 3 maggio` and
  bare `dix heures` / `Deux.`/`Two.` are rejected, while german/spanish/portuguese accept
  digit dates, times and bare number words.

Nothing here suggests converting any row to selection/self-compare: every flagged prompt
has a dictated passage answer; the issue is always coverage of that answer's valid forms.