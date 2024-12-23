// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC-20.sol";
import "./ERC-721.sol";
import "./ERC-1155.sol";

contract finaL {
    ERC20Basic token;
    NFT nft;
    ERC1155MYTOKEN nftwithsupply;

    struct itemD {
        string name;
        uint256 id;
        address owner;
        uint256 lastBid;
        uint256 highestBid;
        address highestBider;
        address lastHighestBider;
        uint256 auction_time;
        string nft_type;
    }
    uint256 itemID = 1;

    struct listItem {
        uint256 id;
        uint256 listedItemPrice;
        address owner;
        string nft_type;
    }

    constructor(
        address addr1,
        address addr2,
        address addr3
    ) {
        nft = NFT(addr1);
        nftwithsupply = ERC1155MYTOKEN(addr2);
        token = ERC20Basic(addr3);
    }

    // mapping
    mapping(uint256 => itemD) public itemDetails;
    mapping(uint256 => listItem) public ListItem;

    // events
    event createItem(address owner, uint256 id, string name);
    event Bid(address _address, uint256 _bidamount);
    event transfer(address _from, address _to, itemD _item);

     mapping(uint => bundle[]) public bundledata;
    struct bundle {
        uint256 id;
        address _address;
    }
    uint BundleId=1;
    mapping(uint => uint256) bundle_selling_price;
    mapping(uint => itemD) bundle_auction_data;

    mapping(uint => listItem) public sell;
    mapping(uint => itemD) public AuctionMap;

    
    event bundleCreated(uint _BundleId,uint[],uint Price);
    event bundleOwnerChange(uint ,uint[],uint);

    //functions

    function bundlelist(
        bool _sell,
        bool _auction,
        uint256[] calldata id_array,
        uint256 price
    ) public {
        require(_sell != _auction,"decide want to sell or auction");
        if (_sell) {
            for (uint256 i = 0; i < id_array.length; i++) {
                require(
                    nft.ownerOf(id_array[i]) == msg.sender,
                    "you are not owner"
                );
                bundledata[BundleId].push(
                    bundle(id_array[i], msg.sender)
                    
                );
                
            }
            bundle_selling_price[BundleId] = price;
            emit bundleCreated(BundleId,id_array,bundle_selling_price[BundleId]);
            BundleId++ ;
        } else if (_auction) {
            for (uint256 i = 0; i < id_array.length; i++) {
                require(
                    nft.ownerOf(id_array[i]) == msg.sender,
                    "you are not owner"
                );
                bundledata[BundleId].push(
                    bundle(id_array[i], msg.sender)
                );
            }
            bundle_auction_data[BundleId] = itemD({
                // tokenId : BundleId,
                // TypeToken:"Erc721",
                // amount : 1,
                // timestamp : block.timestamp,
                // owner : msg.sender,
                // previousBid:0,
                // currentBid : 0,
                // previousBidder :address(0),
                // CurrentBider : address(0),
                // AuctionTime: block.timestamp + 3600,

                
                nft_type : _nft_type,
                owner : msg.sender,
                lastBid : 0,
                highestBid : 0,
                highestBider : address(0),
                lastHighestBider : address(0),
                auction_time:block.timestamp + 3600

            });
            emit bundleCreated(BundleId,id_array,0);
            BundleId++;
        }
    }

    function buy_bundle(uint _BundleId) public payable {
        require(
            bundle_selling_price[_BundleId] == msg.value,
            "you are not paying enough ether"
        );
        for (uint256 i = 0; i < bundledata[_BundleId].length; i++) {
            nft.transferFrom(
                bundledata[_BundleId][i]._address,
                msg.sender,
                bundledata[_BundleId][i].id
            );
        }
        //emit  bundleOwnerChange(_BundleId,bundledata[_BundleId].bundle());
        delete bundledata[_BundleId];
    }

    function cancel_bundle(uint _BundleId) public {
        require(msg.sender == bundledata[_BundleId][0]._address,"you are not the owner to cancel");
        delete bundledata[_BundleId];
        delete bundle_selling_price[_BundleId];
        delete bundle_auction_data[_BundleId];
    }

    function bundle_bid(uint _BundleId,uint amount) public payable returns(string memory) {
        require(_BundleId != 0,"item is not registed for auction");
        require(block.timestamp <bundle_auction_data[_BundleId].AuctionTime,"auction time already ended so please cancel or end the auction");
        require(amount >bundle_auction_data[_BundleId].currentBid,"Bid is not higher than previous bid");
        if(bundle_auction_data[_BundleId].currentBid == 0){
            require(msg.sender != bundle_auction_data[_BundleId].owner," owner can't BID");
            bundle_auction_data[_BundleId].currentBid = amount;
            bundle_auction_data[_BundleId].CurrentBider = msg.sender;
            }
        else if(bundle_auction_data[_BundleId].currentBid !=0) {
            bundle_auction_data[_BundleId].previousBid = bundle_auction_data[_BundleId].currentBid ;
            bundle_auction_data[_BundleId].previousBidder =  bundle_auction_data[_BundleId].CurrentBider;
            bundle_auction_data[_BundleId].currentBid = amount;
            bundle_auction_data[_BundleId].CurrentBider = msg.sender;
            payable(bundle_auction_data[_BundleId].previousBidder).transfer(bundle_auction_data[_BundleId].previousBid);
            }
        return "bid successfully done";
        }
    

    function HighestBundleBid(uint _BundleId) public view returns(uint,address)
    {
        return (bundle_auction_data[_BundleId].currentBid, bundle_auction_data[_BundleId].CurrentBider);
    }  


    function BundleAuctionEnds(uint Id) public payable 
    {
        require(bundle_auction_data[Id].currentBid!=0,"firstly place a bid");
        payable(bundle_auction_data[Id].owner).transfer(bundle_auction_data[Id].currentBid);
        bundle_auction_data[Id].owner = payable(bundle_auction_data[Id].CurrentBider);
        bundle_auction_data[Id].previousBid = bundle_auction_data[Id].currentBid ;
        bundle_auction_data[Id].previousBidder =  bundle_auction_data[Id].CurrentBider;
        bundle_auction_data[Id].currentBid = 0;
        bundle_auction_data[Id].CurrentBider = address(0);
        nft.transferFrom(msg.sender,bundle_auction_data[Id].owner,Id); 
        

    }


    function BundlecancelAuction(uint Id) public payable returns(string memory)
    {
        require(bundle_auction_data[Id].currentBid!=0,"firstly place a bid");
        payable(bundle_auction_data[Id].CurrentBider).transfer(bundle_auction_data[Id].currentBid);
        bundle_auction_data[Id].previousBid = 0 ;
        bundle_auction_data[Id].previousBidder =  address(0);
        bundle_auction_data[Id].currentBid = 0;
        bundle_auction_data[Id].CurrentBider = address(0);
        return ("Auction is been canceled");
    } 

 
    function Register(
        string memory _name,
        string memory _nft_type,
        address _owner,
        uint256 _listedItemPrice,
        uint256 _id,
        string memory checkListAuction
    ) public {
        if (keccak256(abi.encodePacked(checkListAuction)) ==keccak256(abi.encodePacked("Auction"))) {
            require(nft.ownerOf(itemID) == msg.sender ||nftwithsupply.balanceOf(msg.sender, itemID) > 0, "not authorized" );
            require(token.balanceOf(msg.sender) > 0, "Insufficient tokens");
            if ( keccak256(abi.encodePacked(_nft_type)) ==keccak256(abi.encodePacked("ERC721"))) {
                itemDetails[itemID].name = _name;
                itemDetails[itemID].id = _id;
                itemDetails[itemID].nft_type = _nft_type;
                itemDetails[itemID].owner = msg.sender;
                itemDetails[itemID].lastBid = 0;
                itemDetails[itemID].highestBid = 0;
                itemDetails[itemID].highestBider = address(0);
                itemDetails[itemID].lastHighestBider = address(0);
                itemDetails[itemID].auction_time=block.timestamp + 3600;
                itemID += 1;
            } 
            else if(keccak256(abi.encodePacked(_nft_type)) == keccak256(abi.encodePacked("ERC1155"))) {
                itemDetails[itemID].name = _name;
                itemDetails[itemID].id = _id;
                itemDetails[itemID].owner = msg.sender;
                itemDetails[itemID].lastBid = 0;
                itemDetails[itemID].highestBid = 0;
                itemDetails[itemID].highestBider = address(0);
                itemDetails[itemID].lastHighestBider = address(0);
                itemDetails[itemID].auction_time=block.timestamp + 3600;
                itemID += 1;
            }
        } 
        else if (keccak256(abi.encodePacked(checkListAuction)) ==keccak256(abi.encodePacked("Fixed_Price")) ) {
            if (keccak256(abi.encodePacked(_nft_type)) ==keccak256(abi.encodePacked("ERC721")) ) {
                ListItem[itemID].listedItemPrice = _listedItemPrice;
                ListItem[itemID].owner = _owner;
                ListItem[itemID].id = _id;
                ListItem[itemID].nft_type = _nft_type;
                itemID += 1;
            }
             else if (keccak256(abi.encodePacked(_nft_type)) ==keccak256(abi.encodePacked("ERC1155")) ) {
                ListItem[itemID].listedItemPrice = _listedItemPrice;
                ListItem[itemID].owner = _owner;
                ListItem[itemID].id = _id;
                ListItem[itemID].nft_type = _nft_type;
                itemID += 1;
            }
        }
    }

    function placeBid(uint256 itemID, uint256 _amount)
        public
        payable
        returns (string memory){
        require(itemDetails[itemID].auction_time > block.timestamp,  "not started yet");
        require(_amount > itemDetails[itemID].lastBid, "Increase the Amount");
        require(itemDetails[itemID].owner != msg.sender, " owner can't bid");
        itemDetails[itemID].lastBid = itemDetails[itemID].highestBid;
        itemDetails[itemID].lastHighestBider = itemDetails[itemID].highestBider;
        itemDetails[itemID].highestBid = _amount;
        itemDetails[itemID].highestBider = msg.sender;
        payable(itemDetails[itemID].lastHighestBider).transfer(itemDetails[itemID].lastBid);
        emit Bid(msg.sender, _amount);
        return "Bid successfully Completed";
    }

    function LowerthePrice(uint256 itemID, uint256 loweredamount) public payable {
        require(
            msg.sender == ListItem[itemID].owner,
            "Only owner can lower the price"
        );
        require(
            loweredamount < ListItem[itemID].listedItemPrice,
            "Amount should be smaller then the previous one "
        );
        ListItem[itemID].listedItemPrice = loweredamount;
    }

    function getHighestBid(uint256 id) public view returns (uint256) {
        return itemDetails[id].highestBid;
    }

    function cancelListing(uint256 itemID) public {
        // require(ListItem[itemID].listedItemPrice > 0 ,"Item did't exist");
        require(msg.sender == ListItem[itemID].owner,  "Only owner can cancel listing"  );
        delete ListItem[itemID];
    }

    function cancelAuction(uint256 id) public {
        require(itemDetails[id].highestBid > 0, "Auctioned item didnt exist");
        require( msg.sender == itemDetails[id].owner," Only Owner can cancel the Auction" );
        payable(itemDetails[id].highestBider).transfer( itemDetails[id].highestBid );
        delete itemDetails[id];
    }

    function getcontractaddress() public view returns (address) {
        return address(this);
    }
}
