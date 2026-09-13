# Rescue Triage — application iOS de démonstration

**Date :** 2026-09-13
**Statut :** design validé, prêt pour le plan d'implémentation
**Dépôt :** `poneylfe-lang/rescue-triage-ios` (public)

## 1. Objet

Application iPhone démontrant le tri d'invendus de Rescue, le supermarché
anti-gaspi de Rīga (Miera iela 58). L'opérateur part d'une déclaration
fournisseur, photographie le produit, et obtient un verdict motivé :
**accepté**, **suspendu à jugement humain**, ou **refusé**.

L'application reprend le modèle déjà présent dans l'onglet « The pipeline » du
site concept (`~/Claude/rescue/public/index.html`) plutôt que d'en inventer un
nouveau : mêmes verdicts `pass` / `hold` / `rej`, même score sur 10, mêmes
enseignes, même vocabulaire de motifs de refus.

Public visé : investisseurs et partenaires enseignes, en démonstration tenue à
la main.

## 2. Périmètre

**Inclus.** Lots de démonstration pré-chargés ; formulaire de saisie manuelle ;
capture photo (caméra ou photothèque) ; analyse visuelle par l'API Gemini ;
moteur de règles sanitaires local ; carte de verdict ; arbitrage humain sur les
cas suspendus ; bilan de session cumulatif ; écran de réglages avec stockage de
la clé d'API au Keychain.

**Exclus délibérément.** Import CSV ; analyse de texte collé ; backend ; comptes
utilisateurs ; intégration réelle aux systèmes des enseignes ; persistance
au-delà de la session ; localisation multilingue. L'interface est en anglais,
comme la langue principale du site.

**Hypothèse à confirmer.** Interface en anglais. Si les démonstrations se font
en français ou en letton, c'est une décision à prendre avant l'implémentation,
pas après.

## 3. Modèle de données

### 3.1 `SupplierDeclaration` — ce que le fournisseur affirme

| Champ | Type | Notes |
|---|---|---|
| `supplier` | `String` | Rimi, Maxima, Lidl, Sky&More, Barbora, Elvi, top!, Mego, Aibe, LaTS, Your Neighbour Grocery, Baltic Fresh |
| `productName` | `String` | |
| `category` | `ProductCategory` | `dairy`, `bakery`, `produce`, `meatFish`, `chilledPrepared`, `frozen`, `ambient` |
| `quantity` / `unit` | `Double` / `String` | |
| `arrivalDate` | `Date` | Date d'arrivée chez le fournisseur |
| `expiryDate` | `Date` | |
| `expiryKind` | `ExpiryKind` | `useBy` (DLC) ou `bestBefore` (DDM) |
| `declaredReason` | `RejectReason` | voir 3.4 |
| `coldChainGapMinutes` | `Int?` | `nil` = aucune rupture déclarée |
| `storageTempC` | `Double?` | |
| `retailUnitPrice` | `Decimal` | sert au calcul de valeur récupérée |
| `estimatedWeightKg` | `Double` | sert au calcul de masse détournée |

La distinction `useBy` / `bestBefore` est la ligne rouge du domaine. Une **DLC**
dépassée est un refus sanitaire sans appel. Une **DDM** dépassée reste
légalement vendable et constitue le fonds de commerce de Rescue. Un système qui
confond les deux jette de la nourriture saine, ou en vend de la dangereuse.
`ExpiryKind` n'a donc pas de valeur par défaut : chaque déclaration doit la
porter explicitement.

### 3.2 `ScanObservation` — ce que Gemini voit

| Champ | Type |
|---|---|
| `damageSeverity` | `Int` 0–4 |
| `packagingIntegrity` | `intact` \| `dented` \| `compromised` \| `breached` |
| `spoilageSigns` | `[String]` — moisissure, décoloration, suintement… |
| `labelLegible` | `Bool` |
| `observedProduct` | `String` |
| `observedQuantityPlausible` | `Bool` |
| `discrepancies` | `[Discrepancy]` |
| `visualNotes` | `String` |

`Discrepancy` = `{ field, declared, observed, severity: minor | major }`.

Les écarts sont la raison d'être du scan : vérifier si le fournisseur dit vrai.
Un bon annonçant « carton légèrement bosselé » face à une photo montrant un
emballage percé doit produire un écart `major`.

### 3.3 `Verdict`

| Champ | Type |
|---|---|
| `outcome` | `accepted` \| `heldForHuman` \| `rejected` |
| `score` | `Double` 0–10 |
| `reasons` | `[VerdictReason]` — code + libellé |
| `discrepancies` | `[Discrepancy]` |
| `vetoed` | `Bool` — vrai si une règle sanitaire a imposé le refus |
| `humanOverride` | `Outcome?` — renseigné par l'arbitrage |

### 3.4 `RejectReason` — vocabulaire repris du site

`endOfDayBake`, `hailMarks`, `calibreOut`, `oldPackaging`, `sellByTomorrow`,
`shortShelfLife`, `discontinued`, `postPromoOverstock`, `spottySkin`,
`overproduction`, `dentedOuterBox`, `holidaySurplus`, `packagingRedesign`,
`shortDatedBatch`, `gradedOutForShape`, `coldChainGap`.

Chacun porte un booléen `isCosmetic`. Tous sont cosmétiques ou commerciaux sauf
`coldChainGap`. Les motifs cosmétiques **n'entraînent aucune pénalité de score** :
c'est l'inversion qui définit Rescue. Ce qu'un supermarché refuse, nous le
vendons.

## 4. Répartition des responsabilités

**Gemini n'établit pas le verdict.** Il analyse la photo, rien de plus.

Les règles sanitaires sont de l'arithmétique : une date est dépassée ou elle ne
l'est pas. Déléguer ce calcul à un modèle de langage revient à accepter qu'il se
trompe un jour sur une soustraction de dates, alors que le résultat affirme
qu'un produit est propre à la vente.

| Composant | Responsabilité | Réseau |
|---|---|---|
| `SafetyRules` | dates, chaîne du froid, températures | non |
| `GeminiClient` | état visuel, détection d'écarts | oui |
| `VerdictEngine` | fusion, avec veto sanitaire prioritaire | non |

Conséquence : si Gemini est lent, indisponible ou que la clé expire,
l'application rend toujours un verdict réglementaire défendable, signalé comme
partiel. La démonstration ne tombe jamais en panne sèche.

## 5. Règles sanitaires

### 5.1 Refus sans appel (veto)

Ces conditions imposent `rejected` quel que soit le score.

1. `expiryKind == .useBy` et `expiryDate < aujourd'hui`.
2. `packagingIntegrity == .breached` sur un produit alimentaire scellé.
3. `spoilageSigns` non vide.
4. Rupture de chaîne du froid au-delà du seuil de la catégorie (5.2).
5. Température de stockage au-delà du seuil de la catégorie (5.3).

### 5.2 Seuils de rupture de chaîne du froid

| Catégorie | Accepté | Suspendu | Refusé |
|---|---|---|---|
| `meatFish` | 0 min | 1–15 min | > 15 min |
| `dairy`, `chilledPrepared` | ≤ 15 min | 16–30 min | > 30 min |
| `frozen` | 0 min | 1–20 min | > 20 min |
| `bakery`, `produce`, `ambient` | sans objet | — | — |

### 5.3 Seuils de température

| Catégorie | Conforme | Suspendu | Refusé |
|---|---|---|---|
| `dairy`, `chilledPrepared`, `meatFish` | ≤ 4 °C | 4,1–8 °C | > 8 °C |
| `frozen` | ≤ −18 °C | −17,9 à −12 °C | > −12 °C |
| autres | sans objet | — | — |

### 5.4 Péremption

- **DLC dépassée** → refus (veto).
- **DLC aujourd'hui** → accepté, marqué `sellToday`. −1,0 au score.
- **DLC future** → aucun effet.
- **DDM dépassée ≤ 30 j** → accepté, −0,5.
- **DDM dépassée 31–90 j** → suspendu.
- **DDM dépassée > 90 j** → refusé pour qualité invendable (sans veto sanitaire).

## 6. Score et bandes de verdict

Départ à 10,0, puis déductions :

| Facteur | Déduction |
|---|---|
| `damageSeverity` | −1,5 par niveau |
| `packagingIntegrity == .dented` | −0,5 |
| `packagingIntegrity == .compromised` | −2,0 |
| DLC aujourd'hui | −1,0 |
| DDM dépassée | −0,5 par tranche de 30 jours |
| Rupture de froid tolérée | −1,0 par tranche de 10 min |
| `labelLegible == false` | −0,5 |
| Écart `minor` | −1,0 |
| Écart `major` | −2,0 |
| Motif de refus cosmétique | **0** |

Bandes : **≥ 7,0** accepté · **4,0 – 6,9** suspendu · **< 4,0** refusé.

Ces bandes reproduisent exactement les données du site : 8,6 `pass`, 7,1 `pass`,
6,2 `hold`, 3,4 `rej`, 9,0 `pass`, 8,1 `pass`. L'application et le site
resteront cohérents en démonstration.

### Ordre de priorité

Les règles de la section 5 et le score de la section 6 peuvent diverger.
`VerdictEngine` les combine dans cet ordre strict, le premier qui s'applique
l'emportant :

1. **Veto sanitaire (5.1)** → `rejected`, `vetoed = true`. Rien ne l'annule.
2. **Refus qualité (DDM > 90 j)** → `rejected`, `vetoed = false`.
3. **Plancher imposé par une règle** → un seuil « suspendu » de la section 5,
   ou tout écart `major`, force au minimum `heldForHuman`, même si le score
   dépasse 7,0. Un fournisseur qui se trompe — ou qui ment — mérite un œil
   humain, pas un tampon automatique.
4. **Bandes de score** → le verdict par défaut.

Autrement dit, une règle ne peut que **dégrader** le verdict issu du score,
jamais l'améliorer.

## 7. Intégration Gemini

- Point d'entrée : `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`
- Modèle par défaut : `gemini-2.5-flash`, **modifiable dans les réglages** sans
  recompilation — les identifiants de modèles évoluent plus vite qu'un cycle de
  build.
- Image transmise en `inlineData` base64, JPEG recompressé à 1568 px sur le
  grand côté.
- `responseMimeType: "application/json"` **et** `responseSchema` décrivant
  `ScanObservation`. La réponse est donc structurée par construction : pas
  d'analyse de texte libre, pas de démonstration qui s'effondre parce que le
  modèle a répondu en prose ce jour-là.
- Délai d'attente 20 s, une seule reprise, puis repli sur verdict réglementaire
  seul.
- La déclaration fournisseur est envoyée dans le prompt pour permettre la
  détection d'écarts.

### Sécurité de la clé

La clé est saisie une fois dans l'écran Réglages et rangée dans le **Keychain
iOS** (`kSecClassGenericPassword`, accessibilité
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`). Elle n'apparaît jamais dans le
code source, jamais dans un fichier du dépôt, jamais dans les journaux. Le
`.gitignore` bloque en outre tout fichier de secrets créé par accident.

Le dépôt étant public, ce point n'est pas négociable.

## 8. Architecture

SwiftUI, iOS 17+, **aucune dépendance externe**. Rien à télécharger au build,
rien qui casse dans six mois.

```
RescueTriage/
├── Models/     Declaration, Observation, Verdict, DemoBatch, ProductCategory
├── Rules/      SafetyRules.swift, VerdictEngine.swift   ← pur, sans I/O
├── Vision/     GeminiClient.swift, ObservationSchema.swift
├── Store/      SessionStore.swift, KeychainStore.swift
├── Views/      QueueView, DeclarationView, ScanView, AnalyzingView,
│               VerdictCardView, SessionSummaryView, SettingsView
├── Theme/      RescuePalette.swift
└── Resources/  DemoBatches.json, SamplePhotos/
```

`SafetyRules` et `VerdictEngine` sont des fonctions pures : aucune entrée-sortie,
aucune dépendance à `URLSession` ni à l'horloge système (la date du jour est
injectée). Elles sont donc testables exhaustivement et rapidement.

Le projet Xcode utilise les **groupes synchronisés** (`PBXFileSystemSynchronizedRootGroup`,
Xcode 16+) : les fichiers présents sur le disque sont inclus automatiquement.
Le `project.pbxproj` reste donc court et lisible, et l'ajout d'un fichier ne
demande aucune manipulation dans l'interface d'Xcode.

## 9. Parcours

1. **Queue** — lots de démonstration, bouton de saisie manuelle, bandeau de
   bilan de session en haut.
2. **Declaration** — champs relus et corrigeables avant scan.
3. **Scan** — caméra ou photothèque. *Le simulateur iOS n'a pas de caméra* :
   une dizaine de photos de démonstration sont embarquées dans l'application.
   C'est aussi un filet de sécurité si l'éclairage de la salle est mauvais.
4. **Analyzing** — indicateur de progression.
5. **Verdict** — carte en couleur pleine : citron `#d8fb45` accepté, ambre
   `#e0a32e` suspendu, orange `#e8562f` refusé. Score, motifs, écarts signalés.
   Sur un cas suspendu, deux boutons d'arbitrage humain — le geste que le site
   décrit par « People spot-check ».
6. Retour à la file, bilan mis à jour.

**Bilan de session :** articles triés, répartition des verdicts, kilogrammes
détournés de la benne, valeur récupérée en euros. Il transforme une
démonstration technique en démonstration de modèle économique.

## 10. Lots de démonstration

Douze lots issus du vocabulaire du site, couvrant chaque chemin de décision.

| Enseigne | Article | Catégorie | Verdict attendu |
|---|---|---|---|
| Rimi | 42 rye loaves · end-of-day bake | bakery | accepté |
| Elvi | 6 crates apples · hail marks, calibre 61 mm | produce | accepté |
| Barbora | 18 L milk · old carton design | dairy | accepté |
| Baltic Fresh | 30 banana bunches · spotty skin | produce | accepté |
| top! | 1 case passata · dented outer box | ambient | accepté |
| Aibe | 5 kg coffee · packaging redesign | ambient | accepté |
| Your Neighbour Grocery | 12 curd packs · post-promo overstock | dairy | accepté |
| Lidl | 9 chicken trays · sell-by tomorrow | meatFish | accepté |
| Mego | 8 ready meals · kitchen overproduction, DLC aujourd'hui | chilledPrepared | accepté, `sellToday` |
| Maxima | 24 salad bags · 2 days of shelf life left | produce | dépend de la photo |
| LaTS | 1 pallet pasta · discontinued shape, DDM dépassée 45 j | ambient | suspendu |
| Sky&More | 1 case yoghurt · cold-chain gap 40 min | dairy | **refusé (veto)** |

Le lot Sky&More est le cas pédagogique : le score visuel peut être excellent, le
verdict reste un refus. Il démontre que le veto sanitaire prime sur l'apparence.

## 11. Tests

`SafetyRulesTests` et `VerdictEngineTests`, en XCTest, sur fonctions pures :

- Frontières de péremption : DLC hier / aujourd'hui / demain, pour chaque
  `ExpiryKind`.
- Chaque seuil de chaîne du froid, à la valeur limite et de part et d'autre.
- Chaque seuil de température, idem.
- Priorité du veto : un produit de score 9,5 avec DLC dépassée est refusé.
- Écart `major` forçant `heldForHuman` malgré un score ≥ 7,0.
- Motifs cosmétiques n'entraînant aucune déduction.
- Les douze lots de démonstration produisant le verdict attendu du tableau 10,
  chacun associé à une `ScanObservation` synthétique fixe. Le verdict testé est
  donc déterministe : ces tests valident le moteur de décision, jamais le
  jugement de Gemini, qui n'est pas reproductible et n'a pas sa place dans une
  suite de tests.

`GeminiClient` est testé sur le décodage d'une réponse enregistrée, sans appel
réseau.

## 12. Risques

| Risque | Traitement |
|---|---|
| Clé d'API absente ou expirée | Repli sur verdict réglementaire, bandeau explicite |
| Pas de réseau en salle de pitch | Idem ; les lots restent démontrables |
| Identifiant de modèle Gemini obsolète | Modifiable dans les réglages sans rebuild |
| Simulateur sans caméra | Photos de démonstration embarquées |
| Dépôt public | `.gitignore` verrouillé, clé au Keychain uniquement |
| Jugement visuel de Gemini surprenant | Le veto sanitaire borne les conséquences ; l'arbitrage humain existe |

## 13. Livraison

Installation sur l'iPhone via Xcode et Apple ID gratuit : l'application expire
au bout de 7 jours et doit être réinstallée. Un compte développeur Apple
(99 €/an) lève cette limite et ouvre TestFlight. Cette décision peut attendre
la fin de l'implémentation.
