# Gut Log

A personal diary for meals, gut symptoms, and stools. It runs on the iPhone and on a paired Apple Watch. There is no account and no server. The Watch copies logs to and from the iPhone over Watch Connectivity.

The iPhone app has two screens: Today and Export. Today is the diary for one day. The arrows move to the previous or next day, and tapping the Today tab while you are already on it returns to the current day. Editing an entry opens as its own sheet, with Cancel and Save. The app does not score or diagnose anything.

The Watch app is the same diary, built for a small screen. Symptom is a list of types, then a 0–10 slider that also takes the Digital Crown. Stool is the seven Bristol types. Meal is a recent name from the last 14 days, or a new name by typing or dictation. Nutrition stays on the iPhone.

Opening either app syncs. The Watch asks the iPhone for the log, and the iPhone sends the last 21 days. A new entry or a delete on the Watch is queued to the iPhone. Older entries stay on the iPhone.

Optional nutrition fields and three symptom types can be written to Apple Health on the iPhone. Gut Log does not read other Health data. The Watch does not write Health samples. The iPhone writes them the next time Today is open, for rows that do not already have a Health sample.

A meal is written only for the numbers you fill in:

- Energy (kcal) → Dietary Energy
- Protein → Dietary Protein
- Carbohydrates → Dietary Carbohydrates
- Fat → Dietary Fat
- Fibre → Dietary Fiber
- Water (ml) → Dietary Water

These symptoms are written. Severity is stored as not present, mild, moderate, or severe:

- Bloating → Bloating
- Upper abdominal pain → Abdominal Cramps
- Diarrhoea → Diarrhea

Stools, Bristol type, and every other symptom stay in Gut Log only. Editing or deleting an entry on the iPhone removes the Apple Health samples this app wrote.

Requires iOS 17 or later and watchOS 10 or later. The Watch app includes an arm64_32 slice for Apple Watch Series 6. Built for a personal Apple ID team, so it is installed from Xcode with Developer Mode turned on for the iPhone and the Watch. Deleting the iPhone app deletes the diary. Updating it does not.
