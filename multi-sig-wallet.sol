pragma solidity ^0.4.0;

contract MultiSigWallet {
    address private owner;
    
    // Other people can add money to this wallet
    mapping(address => bool) owners;

    // Min amount of signatures needed to validate a transaction
    uint constant private MIN_SIGNATURES = 2;

    // Make an auto incrementing transactionId
    uint private transactionId;
    
    // Make transaction generic
    // First a struct for transaction type
    struct Transaction {
        address from;
        address to;
        uint amount;
        uint8 signatureCount; // The number of owners who have signed this contract
        mapping(address => uint8) signatures; // Make sure 1 owner does not sign contract twice
    }

    // We need an array of Transactions to store them in a queue to exe one Transaction after another
    mapping(uint => Transaction) private transactions;
    // Pending transactions
    uint[] private pendingTransactions;

    modifier isOwner() {
        require(owner == msg.sender);
        _;
    }
    
    // As soon as someone tries to deposit we need to get logs about the operation
    event DepositFunds(address from, uint amount);
    // As soon as someone tries to withdraw log that event
    // 
    event TransactionCreated(address from, address to, uint amount, uint transactionId);
    event TransactionCompleted(address from, address to, uint amount, uint transactionId);
    event TransactionSigned(address by, uint transactionId);
    
    // Check if a given address is one of the owners of the wallet
    modifier isAOwner(address _addr) {
        require(_addr == owner || owners[_addr] == true);
        _;
    }
    
    function MultiSigWallet()
        public {
        owner = msg.sender;
    }
    
    // The current owner (main) can add more owners to this wallet
    function addOwner(address newOwner)
        isOwner
        public {
        owners[newOwner] = true;
    }
    
    // Remove suspicious owner
    function removeOwner(address existingOwner)
        isOwner 
        public {
        delete owners[existingOwner];
    }
    
    // Deposit funds into this wallet
    function deposit()
        isAOwner(msg.sender)
        payable
        public {
        DepositFunds(msg.sender, msg.value);
    }
    
    // Allow a owner to withdra an amount which is not greater than his balance
    function withdraw(uint amount)
        isAOwner(msg.sender)
        public {
        transferTo(msg.sender, amount);
        // require(address(this).balance >= amount);
        // msg.sender.transfer(amount);
        // WithdrawFunds(msg.sender, amount);
    }
    
    // Allow an existing owner to transfer to funds to other people
    function transferTo(address to, uint amount)
        isAOwner(msg.sender)
        public {
        require(address(this).balance >= amount);
        // to.transfer(amount);
        // TransferFunds(msg.sender, to, amount);
        uint currentTransactionId = transactionId++;
        Transaction memory transaction;
        transaction.from = msg.sender;
        transaction.to = to;
        transaction.amount = amount;
        transaction.signatureCount = 0; // This is the beginning of the transfer so nobody has signed it yet

        // Add this to the queue as weill as pending transactions
        transactions[currentTransactionId] = transaction;
        pendingTransactions.push(currentTransactionId);

        // Log the created event
        TransactionCreated(msg.sender, to, amount, currentTransactionId);
    }

    // Utility to get pending transactions
    function getPendingTransactions()
        isOwner
        public
        returns (uint[]) {
        return pendingTransactions;
    }

    function signTransacation(uint transactionToBeSignedId)
        isOwner
        public {
        // Storage, that is take the transaction thats in the storage
        Transaction storage transaction = transactions[transactionToBeSignedId];

        // Make sure that transaction exists in storage
        require(0x0 != transaction.from);
        // The sender of this message should not sign his own transaction
        require(msg.sender != transaction.from);
        // Cannout sign the same transaction more than once
        require(transaction.signatures[msg.sender] != 1);

        // Sign the transaction
        transaction.signatures[msg.sender] = 1;
        // Increase the signature count for this contract after signing
        transaction.signatureCount++;

        // Log an event of transaction signed
        TransactionSigned(msg.sender, transactionToBeSignedId);

        // Check if the number of signatures match the criteria, if yes transact!
        if (transaction.signatureCount >= MIN_SIGNATURES) {
            // Make sure the amount request is not greater than or eqaul to this contracts balance
            require(address(this).balance >= transaction.amount);
            // Go transact this 
            transaction.to.transfer(transaction.amount);
            // Log this event
            TransactionCompleted(transaction.from, transaction.to, transaction.amount, transactionToBeSignedId);
            // delete this transaction and remove it from pendingTranscation
            deleteTransaction(transactionToBeSignedId);
        }
    }

    function deleteTransaction(uint transactionToBeDeletedId)
        isOwner
        public {
        // delete from mapping: simple delete will do
        delete transactions[transactionToBeDeletedId];

        // splicing a dynamic array, (pendingTransactions)
        uint replace = 0; // not found
        for (uint i = 0; i < pendingTransactions.length; i++) {
            if (replace == 1) {
                pendingTransactions[i - 1] = pendingTransactions[i]; // shuffling
            }
            if (pendingTransactions[i] == transactionToBeDeletedId) {
                replace = 1; // found
            }
        }

        // dynamic array has been shuffled to make the last ele redundant so delete that empty space
        delete pendingTransactions[pendingTransactions.length - 1];
        // decrease the length of pending transactions
        pendingTransactions.length--;  
    }

    // get the balance of this waller
    function getWalletBalance()
        isOwner
        constant
        public
        returns (uint) {
        return address(this).balance; // this is the current contract
    }
}
