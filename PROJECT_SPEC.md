# Offline Crop Health and Economic Advisory

## Product goal

Build an offline-first Flutter application for smallholder Indian farmers that helps them screen crop-health problems, collect high-quality field evidence, receive conservative economic guidance, and connect uncertain cases to verified advisers.

This is a hackathon prototype. It must be explicit that the initial model is a screening aid, not a validated clinical/agronomic authority.

## Target users

- Smallholder farmers using low-cost Android phones and unreliable 2G.
- Field workers who collect and verify crop observations.
- Agronomists who review uncertain cases and improve labels.
- Administrators who publish content, model versions, and language packs.

## Initial crop and disease scope

The initial Hugging Face baseline supports:

- Sugarcane: bacterial blight, red rot, healthy.
- Corn: common rust, gray leaf spot, leaf blight, healthy.
- Potato: early blight, late blight, healthy.
- Rice: bacterial blight, blast, brown spot, false smut, leaf blast, healthy.
- Wheat: brown rust, yellow rust, healthy.

Unsupported crops must result in an explicit unsupported/unknown state, never an automatic healthy diagnosis.

## Mobile application

### Core screens

1. Language and farmer profile.
2. Home: scan, history, crop diary, prices, help.
3. Crop selection.
4. Photo coach.
5. Symptom questions.
6. Diagnosis result.
7. Treat/sell/abandon comparison.
8. Submit observation for review.
9. Follow-up case.
10. Offline sync status.

### Photo workflow

Request, where practical:

- whole-plant image;
- affected-leaf close-up;
- underside of leaf;
- stem, fruit, or cob image when relevant.

Run blur, glare, framing, and plant-coverage checks before inference. Store the original locally and create a compressed thumbnail for sync.

### Diagnosis behavior

The app must display:

- crop and disease label;
- model version;
- low/medium/high certainty, not an uncalibrated probability presented as fact;
- photo-quality status;
- alternative possibilities when appropriate;
- reason for abstaining;
- request for another image or expert review.

It must never provide pesticide instructions solely from a high softmax score.

### Voice and languages

Initial languages: Hindi, Marathi, and Telugu.

Use short prompts, constrained answers, replay, visual choices, and tap fallback. Voice recognition failure must not prevent use of the app. Do not rely on unrestricted offline dictation for diagnosis.

## Data-collection workflow

### Farmer observation form

- crop and variety if known;
- growth stage;
- approximate affected area;
- visible symptoms;
- recent spray or fertilizer use;
- irrigation/weather context;
- whole-plant and close-up images;
- approximate location only with consent;
- consent to use the case for model improvement.

### Verified field-worker form

- confirmed diagnosis;
- alternative diagnoses considered;
- severity;
- evidence used;
- treatment or management action;
- follow-up result after 7–14 days;
- reviewer confidence;
- laboratory confirmation, if any.

Farmer reports are not ground truth. Cases enter training only after review, adjudication, or documented follow-up.

Case states:

```text
submitted -> quality_checked -> awaiting_review -> verified -> training_candidate
```

## Offline-first design

Use a local SQLite database and append-only outbox.

Every observation has a stable client-generated ID. Synchronization is idempotent, resumable, and ordered by value:

1. diagnosis metadata;
2. labels and corrections;
3. thumbnails;
4. full-resolution images when permitted.

Show the age of cached prices and content. Diagnosis, history, and forms must remain usable without connectivity.

## Backend

Recommended initial stack:

- FastAPI;
- PostgreSQL;
- S3-compatible object storage;
- background review/processing queue;
- signed model/content manifests;
- admin review API and dashboard.

Core entities:

- users and roles;
- observations;
- images;
- model predictions;
- verified labels;
- follow-ups;
- price snapshots;
- agronomy content;
- model versions;
- audit events.

## ML integration

Use the Hugging Face ViT-Tiny baseline as the first model. Convert its Safetensors artifact to ONNX for Flutter/ONNX Runtime Mobile. Preserve the model's preprocessing configuration.

Before release, test:

- model loading;
- label mapping;
- preprocessing equivalence;
- CPU inference on an inexpensive Android device;
- unsupported-crop behavior;
- malformed and low-quality images;
- server/mobile output consistency.

The model card does not establish field accuracy, calibration, or agronomic safety. Those limitations must be visible in the prototype.

## Economic advisory

Use Agmarknet-derived price snapshots for commodity, variety, market, date, minimum, maximum, and modal price where available. Treat the value as wholesale market information, not guaranteed farm-gate revenue.

Estimate:

```text
net_price = mandi_price - transport - fees - expected sorting loss
expected_value(action) = expected_recoverable_yield * net_price - action_cost - delay_cost
```

Compare treat, sell, and abandon/salvage. If price age, diagnosis confidence, crop mapping, or cost inputs are inadequate, show an uncertainty warning rather than a forced recommendation.

Include a warning that simultaneous adoption of a sell recommendation can increase arrivals and reduce realized prices. Do not claim to predict this effect without local supply-response data.

## Safety and privacy

- Explain that results are screening guidance.
- Abstain for low quality, unsupported crop, OOD image, conflicting symptoms, or insufficient evidence.
- Do not prescribe chemicals without verified crop-specific guidance, dosage, waiting period, and safety information.
- Collect approximate location only with consent.
- Remove or flag faces and unrelated personal information in images.
- Keep an audit trail of predictions, model versions, reviewer changes, and published advice.

## Minimum demo acceptance criteria

- Works with airplane mode enabled after initial installation.
- Captures and stores a diagnosis locally.
- Produces a result for the five supported crop groups.
- Abstains on an unsupported crop or deliberately bad image.
- Syncs a case after connectivity returns.
- Shows a price-data timestamp.
- Allows a verified reviewer to correct a case.
- Preserves both original prediction and verified label.
- Demonstrates Hindi, Marathi, and Telugu prompts or language-pack structure.
- Clearly distinguishes prototype screening from validated diagnosis.
