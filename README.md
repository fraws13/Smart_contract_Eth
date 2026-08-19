

# 📄 Q01 Token & Management Smart Contract

Il contratto `Q01` è un token basato sullo standard **ERC20** che integra due sistemi avanzati per la gestione dei fondi: **Gestione delle Task (Attività)** e **Pool di Contribuzione (Raccolte Fondi)**.

È progettato per trattenere i fondi in *escrow* (deposito di garanzia) all'interno del contratto fino al completamento delle attività, garantendo trasparenza e sicurezza nei pagamenti e nelle raccolte collettive.

---

## 🚀 Funzionalità Principali

### 1. Token ERC20 Standard

Estende l'implementazione sicura di OpenZeppelin per gestire un token personalizzato (`Q01`).

* **Minting & Burning:** Creazione e distruzione di token per gestire l'offerta totale.
* **Precisione:** Frazionabile fino a 18 decimali (standard Ethereum).

### 2. Gestione Task (Attività con Ricompensa)

Permette a un utente ("source") di finanziare un'attività definendo in anticipo chi riceverà i fondi e in quali proporzioni.

* **Creazione:** I fondi (`rewardPool`) vengono trasferiti dal creatore al contratto.
* **Distribuzione:** Al completamento, il contratto distribuisce automaticamente le allocazioni predefinite ai destinatari.
* **Annullamento:** Se la task viene annullata, i fondi tornano al creatore originale.

### 3. Contribution Pools (Raccolte Fondi)

Consente di creare pool in cui più utenti possono versare una quota fissa per raggiungere un obiettivo comune.

* **Partecipazione:** Gli utenti versano un costo fisso predefinito (`costPerParticipant`).
* **Flessibilità:** Gli utenti possono annullare la propria partecipazione e ottenere un rimborso prima della chiusura del pool.
* **Completamento/Annullamento:** Se completato, i fondi vanno al destinatario (`recipient`). Se annullato, tutti i partecipanti vengono rimborsati automaticamente.

---

## 🛠 Strutture Dati Principali

### `Task`

Gestisce le ricompense per lavori o attività completate.

```solidity
struct Task {
    address source;                          // Chi finanzia la task
    uint256 rewardPool;                      // Totale token bloccati
    address[] recipients;                    // Destinatari delle ricompense
    mapping(address => uint256) allocations; // Quota per ogni destinatario
    bool isCompleted;                        // Stato della task
}

```

### `ContributionPool`

Gestisce raccolte fondi con quote fisse.

```solidity
struct ContributionPool {
    address recipient;                       // Chi riceverà i fondi
    uint256 totalContributed;                // Totale accumulato
    uint256 costPerParticipant;              // Costo fisso per partecipare
    mapping(address => bool) hasParticipated;// Traccia chi ha partecipato
    bool isCompleted;                        // Stato della raccolta
    mapping(address => uint256) contributions; 
    address[] participants;                  // Lista dei contributori
}

```

---

## 📡 Eventi

Il contratto emette eventi per facilitare il tracciamento off-chain (es. interfacce frontend o dApp):

* `TaskCreated(uint256 taskId, uint256 rewardPool)`
* `RewardsDistributed(uint256 taskId)`
* `ContributionPoolCreated(uint256 poolId, address recipient, uint256 costPerParticipant)`
* `ContributionMade(uint256 poolId, address contributor, uint256 amount)`
* `ContributionPoolCompleted(uint256 poolId, address recipient, uint256 totalAmount)`
* `ContributionPoolCancelled(uint256 poolId)`

---

## ⚠️ Note di Sicurezza e Sviluppi Futuri

Come evidenziato nei commenti del codice sorgente, l'attuale implementazione richiede alcune integrazioni di sicurezza prima del deploy in produzione (Mainnet):

1. **Access Control (Priorità Alta):** Attualmente funzioni critiche come `mint`, `completeTask`, e `cancelTask` sono pubbliche (`public`). È **necessario** implementare `Ownable` o `AccessControl` di OpenZeppelin per limitare queste azioni solo agli amministratori o ai creatori specifici della task.
2. **Gestione Gas (Scalabilità):** Le funzioni `completeTask` e `cancelContributionPool` utilizzano cicli `for` per distribuire token a un array di indirizzi. Se il numero di partecipanti è molto alto, la transazione potrebbe fallire superando il limite di Gas del blocco.
* *Soluzione consigliata:* Implementare un pattern **Pull over Push** (dove gli utenti reclamano autonomamente i propri fondi tramite una funzione `claim()`).


3. **Cap sull'Inflazione:** Si consiglia di aggiungere un limite massimo (Cap) nella funzione `mint` per prevenire la generazione illimitata di token.

---

## 💻 Requisiti e Compilazione

* **Solidity:** `^0.8.0`
* **Dipendenze:** `@openzeppelin/contracts`

Per compilare il contratto usando un framework come Hardhat:

```bash
# Installa le dipendenze
npm install @openzeppelin/contracts

# Compila il contratto
npx hardhat compile

```

## 📜 Licenza

Questo progetto è rilasciato sotto licenza **MIT**.
