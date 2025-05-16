// =====================================================
//  ENV UTILS - Parsing des variables d'environnement
// =====================================================

/**
 * Parse une variable d'environnement numérique et lève une erreur explicite si invalide.
 * @param varName Nom de la variable d'environnement
 * @returns La valeur numérique
 * @throws Si la variable est absente ou non numérique
 */
export function parseNumberEnv(varName: string): number {
    const val = process.env[varName];
    if (val === undefined) {
      throw new Error(`Variable d'environnement manquante : ${varName}`);
    }
    const num = Number(val);
    if (isNaN(num)) {
      throw new Error(
        `La variable ${varName} doit être un nombre valide (reçu : "${val}")`
      );
    }
    return num;
  }