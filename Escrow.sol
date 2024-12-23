// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

contract Escrow {
    enum State{Awaiting_delivery, Awaiting_payment,Completed}
    State public currState;

    address public buyer;
    address payable public seller;

    modifier OnlyBuyer(){
        require(msg.sender == buyer,"Only buyer can call this function");
        _;
    }

    constructor(address _buyer, address payable _seller){
        buyer =_buyer;
        seller = _seller;
    }

    function deposit() OnlyBuyer external payable {
        require(currState == State.Awaiting_delivery,"Already Paid");
        currState = State.Awaiting_payment;
    }

    function ConfirmDelivery() OnlyBuyer external {
        require(currState == State.Awaiting_payment,"Cannot Confirm Delivery");
        seller.transfer(address(this).balance);
        currState = State.Completed;
    }
}