// =====================================================
//  MATH UTILS - Calculs statistiques
// =====================================================

/**
 * Calcule la médiane d'une liste de bigint.
 * @param {bigint[]} values - Tableau de valeurs bigint (non vide)
 * @returns {bigint} La médiane sous forme de bigint
 * @throws {Error} Si le tableau est vide
 */
export function median(values: bigint[]): bigint {
    if (values.length === 0) throw new Error("Aucune valeur pour la médiane");
    const sorted = [...values].sort((a, b) => (a < b ? -1 : 1));
    const mid = Math.floor(sorted.length / 2);
    if ((sorted.length & 1) === 0) {
      return (sorted[mid - 1] + sorted[mid]) / 2n;
    } else {
      return sorted[mid];
  }
}
