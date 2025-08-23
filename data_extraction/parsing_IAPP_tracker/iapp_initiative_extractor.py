import re
import pandas as pd
from typing import List

# === Chargement du fichier Excel IAPP ===
def load_iapp_tracker(path_xlsx: str, policy_col: str = "Specific AI governance law or policy") -> pd.DataFrame:
    df = pd.read_excel(path_xlsx, engine="openpyxl")  # Lecture directe du fichier
    jur_col = df.columns[0]
    if policy_col not in df.columns:
        raise ValueError(f"Column '{policy_col}' not found. Available: {df.columns.tolist()}")
    return df[[jur_col, policy_col]].rename(columns={jur_col: "Juridiction", policy_col: "Policy_Text"})

# === Détection des initiatives ===
YEAR_RE = re.compile(r"\b(19|20)\d{2}\b")
BULLET_RE = re.compile(r"^\s*[•\-\u2022]")
CUE_WORDS = (
    "adopt", "publish", "release", "issue", "enact", "pass", "propos", "draft",
    "develop", "launch", "start", "initiat", "establish", "approve", "announce",
    "update", "introduc", "recognize", "code of practice", "directive",
    "resolution", "bill", "ai act", "strategy", "action plan"
)
START_WORDS = (
    "It ", "The ", "In ", "Under ", "According ", "Further", "Additionally",
    "Parliament", "Government", "Congress"
)
EXCLUDE_OPENERS = re.compile(
    r"(has made policy initiatives on AI|highlighted the application of existing)",
    flags=re.I
)

# === Découper le texte en puces et phrases ===
def split_text_into_bullets_and_sentences(text: str):
    txt = (text or "").replace("\xa0", " ").strip()
    lines = txt.splitlines()
    bullets = [ln.strip(" •-\t") for ln in lines if BULLET_RE.search(ln.strip())]
    non_bullet_lines = [ln for ln in lines if not BULLET_RE.search(ln.strip())]
    non_bullet = "\n".join(non_bullet_lines)
    sentences = re.split(r"(?<=[\.\?\!])\s+(?=[A-Z])", non_bullet)
    sentences = [s.strip() for s in sentences if s and s.strip()]
    return bullets, sentences

# === Identifier si une phrase est une initiative ===
def is_initiative_sentence(s: str) -> bool:
    s_clean = s.strip()
    if len(s_clean) < 20:
        return False
    low = s_clean.lower()
    if any(cw in low for cw in CUE_WORDS):
        return True
    if any(s_clean.startswith(sw) for sw in START_WORDS):
        return True
    if YEAR_RE.search(s_clean):
        return True
    if any(tok in s_clean for tok in ("Bill", "Resolution", "Directive", "Regulation", "Act")):
        return True
    return False

# === Extraire les initiatives d'un texte ===
def extract_initiatives_from_text(text: str):
    bullets, sentences = split_text_into_bullets_and_sentences(text)
    initiatives = bullets + [s for s in sentences if is_initiative_sentence(s)]
    seen = set()
    result = []
    for it in initiatives:
        it = it.strip(" -•\t")
        if not it or it in seen or len(it) < 20:
            continue
        if EXCLUDE_OPENERS.search(it):
            continue
        seen.add(it)
        result.append(it)
    return result

# === Construire le tableau final ===
def build_initiatives_table(df_iapp: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for _, row in df_iapp.dropna(subset=["Policy_Text"]).iterrows():
        jur = str(row["Juridiction"]).strip().upper()
        text = str(row["Policy_Text"])
        initiatives = extract_initiatives_from_text(text)
        for init in initiatives:
            y = YEAR_RE.search(init)
            year = int(y.group(0)) if y else None
            rows.append({
                "Juridiction": jur,
                "Policy_Text": text,
                "Initiative_Résumé": init,
                "Année": year
            })
    out = pd.DataFrame(rows).drop_duplicates()
    return out

# === Main ===
def main(input_xlsx: str, output_csv: str = "initiatives_AI_precises_extraites_auto.csv"):
    df = load_iapp_tracker(input_xlsx)
    out = build_initiatives_table(df)
    out.to_csv(output_csv, index=False, encoding="utf-8")
    print(f"✅ Fichier exporté : {output_csv}")
    return out

# Lancement
if __name__ == "__main__":
    main(
        input_xlsx="global_ai_law_policy_tracker.xlsx",  # fichier dans le même dossier
        output_csv="initiatives_AI_precises_extraites_auto.csv"  # sortie dans le même dossier
    )
