pragma solidity ^0.8.18;
import "hardhat/console.sol"; // used in testing chains

contract MultisigMyself {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed _txId);
    event Approve(address indexed owner, uint256 indexed txId);
    event Revoke(address indexed owner, uint256 indexed txId);
    event Execute(uint256 indexed _txId);

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    address[] public owners;
    uint256 public required;

    mapping(address => bool) public isOwner;

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "You are not owner");
        _;
    }
    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "tx does not existed");
        _;
    }
    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "tx already approved");
        _;
    }
    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "tx already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(_owners.length >= _required && _required > 0, "Invalid required number of owners");

        for (uint256 i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner is not unique");
            isOwner[owner] = true;
            owners.push(owner);

            console.log("New owner added: ", owner);
        }
        required = _required;
        console.log("Constructor is finished");
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(address _to, uint256 _value, bytes calldata data) external onlyOwner{
        transactions.push(Transaction(_to, _value, data, false));
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 _txId) external onlyOwner txExists(_txId) notApproved(_txId) notExecuted(_txId){
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    function revoke(uint256 _txId) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    function execute(uint256 _txId) external txExists(_txId) notExecuted(_txId) {
        require(_getApprovedCount(_txId) >= required, "approvals < required");
        Transaction transaction = transactions[_txId];
        transaction.executed = true;

        (bool success, ) = transaction.to.calldata{value: transaction.value}(transaction.data);
        require(success, "Transaction failed");

        emit Execute(_txId);
        
    }

    function _getApprovedCount(uint256 _txId) private view returns(uint256 count) {
        for (uint256 i; i < owners.length; i++) {
            if(approved[_txId][owners[i]]) {
                count++ ;
            }
        }
    }


}


