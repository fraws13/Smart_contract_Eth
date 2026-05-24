// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


//ci può essere il problema che chiunque poò deployare il contratto 
//chi lo deploya diventa automaticamente admin attraverso l'uso di AccesControll


pragma solidity ^0.8.0;

interface ERC20Basic {

    function totalSupply() external view returns (uint256);
    //Ritorna la quantità totale di token esistenti.
    function balanceOf(address account) external view returns (uint256);
    //Ritorna il saldo di un indirizzo.    

    function transfer(address recipient, uint256 amount) external returns (bool);
    //Trasferisce token a un altro indirizzo

    event Transfer(address indexed from, address indexed to, uint256 value);
    //Traccia i trasferimenti di token.
    
}


contract Q01 is ERC20{

    using SafeMath for uint256;

    // Mapping per tracciare i pool di contribuzione
    mapping(uint256 => ContributionPool) public contributionPools;

    

    struct ContributionPool {
        address recipient; // Destinatario dei fondi
        uint256 totalContributed; // Totale dei fondi accumulati
        uint256 costPerParticipant; // Costo richiesto per partecipare
        mapping(address => bool) hasParticipated; // Stato di partecipazione
        bool isCompleted; // Stato del pool
        mapping(address => uint256) contributions; // Contributi individuali
        address[] participants; // Lista dei partecipanti
    }


    // Mapping per verificare rapidamente se un indirizzo è un admin


    mapping(uint256 => Task) public tasks;


    // Evento per tracciare la creazione di un'attività
    event TaskCreated(uint256 taskId, uint256 rewardPool);
    event ContributionPoolCreated(uint256 poolId, address recipient,uint256 costPerParticipant);
    event ContributionMade(uint256 poolId, address contributor, uint256 amount);
    event ContributionPoolCompleted(uint256 poolId, address recipient, uint256 totalAmount);
    event ContributionPoolCancelled(uint256 poolId);




    // Evento per tracciare la distribuzione delle ricompense
    event RewardsDistributed(uint256 taskId);

    uint256 totalSupply_ = 0 ether;

    uint256 reservedCredits;
    



    constructor()  ERC20("Q01Token", "Q01") {
        //Un token ERC20 può essere frazionato alla 10^-18, stesso livello di precisione di ETH
        

    }

    
    


    struct Task {
        address source;
        uint256 rewardPool; // Totale token per l'attività
        address[] recipients; // Elenco degli indirizzi destinatari
        mapping(address => uint256) allocations; // Allocazioni personalizzate per ogni indirizzo
        bool isCompleted; // Stato dell'attività
    }

    

    // Ritorna la quantità totale di token emessi.
    function totalSupply() public override view returns (uint256) {
        return totalSupply_;
    }

    // Funzione per bruciare (burn) i token, riducendo l'offerta totale.
    //SI POTREBBE IMPLEMENTARE UN CAP PER EVITARE UN INFLAZIONE ECCESSIVA
    function burn(address Address, uint256 amount) public {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(Address) >= amount, "Insufficient balance to burn");

        _burn(Address, amount); // Usa la funzione `_burn` di OpenZeppelin.
    }

    // Genera nuovi token e li assegna all'admin.
    //aggiungere un limite massimo (ad esempio un cap) per prevenire inflazioni eccessive?
    function mint(address Address, uint256 amount) public{
        require(amount > 0, "Amount must be greater than 0");
        totalSupply_ += amount;
        // Incrementa l'offerta totale di token.
        emit Transfer(address(0), Address, amount);
        //Il valore address(0) viene utilizzato come mittente per rappresentare un'operazione di minting. In questo contesto, i token non provengono da un utente, ma vengono creati ex novo
        _mint(Address, amount); // Usa la funzione interna di OpenZeppelin per aggiornare i saldi
    }

    // Ritorna il saldo di un indirizzo specifico.
    function balanceOf(address tokenOwner) public override view returns (uint256) {
        //return balances[tokenOwner];
        return super.balanceOf(tokenOwner);
    }

    // Ritorna il totale dei crediti riservati per le attività
    function getReservedCredits() public view returns (uint256) {
        return reservedCredits;
    }

    
    function createTask(
        uint256 taskId,
        uint256 rewardPool,
        address[] memory recipients,
        uint256[] memory allocations,
        address source
    ) public  {
        require(tasks[taskId].rewardPool == 0, "Task ID already exists");
        require(recipients.length == allocations.length, "Recipients and allocations length mismatch");
        require(source != address(0), "Invalid source address");

        uint256 totalAllocations = 0;

        // Verifica che il source abbia abbastanza saldo disponibile
        uint256 sourceBalance = balanceOf(source);
        require(sourceBalance >= rewardPool, "Source has insufficient balance");

        // Calcola la somma totale delle allocazioni
        for (uint256 i = 0; i < recipients.length; i++) {
            totalAllocations += allocations[i];
        }
        require(totalAllocations == rewardPool, "Allocations do not match reward pool");

        // Inizializza l'attività
        Task storage task = tasks[taskId];
        task.source = source; // Salva il source
        task.rewardPool = rewardPool;
        task.recipients = recipients;
        for (uint256 i = 0; i < recipients.length; i++) {
            task.allocations[recipients[i]] = allocations[i];
        }

        // Deduce il rewardPool dal saldo del source
        _transfer(source, address(this), rewardPool); // Trasferisce i token al contratto

        // Aggiorna i crediti riservati
        reservedCredits += rewardPool;

        emit TaskCreated(taskId, rewardPool);
    }





    
    // Completa un'attività e distribuisce i token ai destinatari(richiede permessi admin).

    //quando ci sono molti partecipanti nella task il processo di distribuzione può essere molto lento
    //si potrebbe implementare una funzione con la quale i partecipanti vadano a richiedere personalmente le ricompense che gli spettano

    function completeTask(uint256 taskId) public  {
        Task storage task = tasks[taskId];
        require(task.rewardPool > 0, "Task does not exist");
        require(!task.isCompleted, "Task already completed");

        // Distribuisce i fondi ai destinatari
        for (uint256 i = 0; i < task.recipients.length; i++) {
            address recipient = task.recipients[i];
            uint256 amount = task.allocations[recipient];
            if (amount > 0) {
                _transfer(address(this), recipient, amount); // Trasferisce i token dal contratto
            }
        }

        // Aggiorna i crediti riservati e lo stato della task
        reservedCredits -= task.rewardPool;
        task.isCompleted = true;

        emit RewardsDistributed(taskId);
    }

    // Annulla una task e restituisce i crediti riservati all'admin(richiede permessi admin).
    function cancelTask(uint256 taskId) public{
        Task storage task = tasks[taskId];
        require(task.rewardPool > 0, "Task does not exist");
        require(!task.isCompleted, "Cannot cancel a completed task");
        // Ritorna i token riservati al proprietario originale (source)
        _transfer(address(this), task.source, task.rewardPool); // Restituisce i fondi al source
        // Riduci i crediti riservati
        reservedCredits -= task.rewardPool;

        // Rimuovi i dettagli della task
        delete tasks[taskId];

        emit TaskCreated(taskId, 0); // Traccia l'annullamento impostando il rewardPool a 0
    }

    // Ritorna la lista dei destinatari di una specifica attività.
    function getRecipients(uint256 taskId) public view returns (address[] memory) {
        return tasks[taskId].recipients;
    }

    function getTaskParticipants(uint256 taskId) public view returns (address[] memory, uint256[] memory) {
        // Verifica che l'attività esista
        require(tasks[taskId].rewardPool != 0, "Task ID does not exist");

        // Ottieni l'attività
        Task storage task = tasks[taskId];

        // Crea array per i partecipanti e le allocazioni
        address[] memory recipients = new address[](task.recipients.length);
        uint256[] memory allocations = new uint256[](task.recipients.length);

        // Popola gli array con i dati dell'attività
        for (uint256 i = 0; i < task.recipients.length; i++) {
            recipients[i] = task.recipients[i];
            allocations[i] = task.allocations[task.recipients[i]];
        }

        // Restituisce i partecipanti e le loro allocazioni
        return (recipients, allocations);
    }


    function createContributionPool(
        uint256 poolId,
        address recipient, //Indirizzo del destinatario che riceverà i fondi
        uint256 costPerParticipant
    ) public {
        require(recipient != address(0), "Invalid recipient address");
        require(contributionPools[poolId].recipient == address(0), "Pool ID already exists");
        require(costPerParticipant > 0, "Cost per participant must be greater than zero");

        ContributionPool storage pool = contributionPools[poolId];
        pool.recipient = recipient;
        pool.costPerParticipant = costPerParticipant;

        emit ContributionPoolCreated(poolId, recipient, costPerParticipant);
    }



    function contributeToPool(address Address, uint256 poolId) public {
        ContributionPool storage pool = contributionPools[poolId];
        require(pool.recipient != address(0), "Pool does not exist");
        require(!pool.isCompleted, "Pool is already completed");
        require(!pool.hasParticipated[Address], "You have already participated");

        uint256 amount = pool.costPerParticipant;
        //vi continua ad esserci la verfica sul fatto che se ha dei crediti riservati non li può spendere
        require(balanceOf(Address) >= amount, "Insufficient balance to participate");

        // Trasferisce i token dal partecipante al contratto
        _transfer(Address, address(this), amount);
        //in questo modo i token destinati all'attività vengono trasferiti al contratto per assicurasi 
        //che i token non vengano spesi prima della chiusura dell'attività

        // Aggiorna i contributi
        pool.totalContributed += amount;
        pool.hasParticipated[Address] = true;
        pool.contributions[Address] = amount;
        pool.participants.push(Address); // Aggiunge il partecipante alla lista

        emit ContributionMade(poolId, Address, amount);
    }


    function cancelParticipation(address Address,uint256 poolId) public {
        ContributionPool storage pool = contributionPools[poolId];

        // Verifica che il pool esista
        require(pool.recipient != address(0), "Pool does not exist");

        // Verifica che il pool non sia già completato
        require(!pool.isCompleted, "Pool is already completed");

        // Verifica che il partecipante abbia effettivamente contribuito
        require(pool.hasParticipated[Address], "You have not participated in this pool");

        // Verifica che il partecipante abbia un contributo valido
        uint256 contribution = pool.contributions[Address];
        require(contribution > 0, "No contribution to refund");

        // Rimborso dei token al partecipante
        _transfer(address(this), Address, contribution);

        // Aggiorna lo stato del pool
        pool.totalContributed -= contribution; // Riduci il totale dei contributi
        pool.hasParticipated[Address] = false; // Rimuovi il partecipante
        pool.contributions[Address] = 0; // Azzera il contributo del partecipante

        // Rimuovi il partecipante dalla lista dei partecipanti
        for (uint256 i = 0; i < pool.participants.length; i++) {
            if (pool.participants[i] == Address) {
                // Sposta l'ultimo elemento nella posizione corrente e riduci la lunghezza dell'array
                pool.participants[i] = pool.participants[pool.participants.length - 1];
                pool.participants.pop();
                break;
            }
        }
    }

    function completeContributionPool(uint256 poolId) public {
        ContributionPool storage pool = contributionPools[poolId];
        require(pool.recipient != address(0), "Pool does not exist");
        require(!pool.isCompleted, "Pool is already completed");
        require(pool.totalContributed > 0, "No contributions made");

        // Trasferisce i fondi al destinatario
        _transfer(address(this), pool.recipient, pool.totalContributed);

        pool.isCompleted = true;

        emit ContributionPoolCompleted(poolId, pool.recipient, pool.totalContributed);
    }

    function cancelContributionPool(uint256 poolId) public{
        ContributionPool storage pool = contributionPools[poolId];
        require(pool.recipient != address(0), "Pool does not exist");
        require(!pool.isCompleted, "Cannot cancel a completed pool");

        // Rimborso dei fondi a ciascun partecipante
        for (uint256 i = 0; i < pool.participants.length; i++) {
            address participant = pool.participants[i];
            uint256 contribution = pool.contributions[participant];
            if (contribution > 0) {
                _transfer(address(this), participant, contribution); // Restituisce i token
            }
        }

        // Elimina il pool
        delete contributionPools[poolId];

        emit ContributionPoolCancelled(poolId);
    }

    function getPoolDetails(uint256 poolId) public view returns (
        address recipient,
        uint256 totalContributed,
        uint256 costPerParticipant,
        bool isCompleted
    ) {
        ContributionPool storage pool = contributionPools[poolId];
        require(pool.recipient != address(0), "Pool does not exist");

        return (
            pool.recipient,
            pool.totalContributed,
            pool.costPerParticipant,
            pool.isCompleted
        );
    }

    function getPoolParticipants(uint256 poolId) public view returns (address[] memory) {
        ContributionPool storage pool = contributionPools[poolId];
        require(pool.recipient != address(0), "Pool does not exist");

        return pool.participants;
    }





}
