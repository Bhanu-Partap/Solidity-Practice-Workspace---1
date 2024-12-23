// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts@4.9.6/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts@4.9.6/utils/math/SafeMath.sol";
import "./ERC721Dynmic.sol";
import "./ERC20Gem.sol";

contract Vault is IERC721Receiver {
    using SafeMath for uint256;
    address public assetToken;
    address public assetCollection;
    address public admin;

    uint256 initialTime;

    uint256 public initialFMV;

    uint256 public vaultCurrentValuation;
    mapping(uint256 => uint256) AssetValuation;
    mapping(address => uint256) ownerToAsset;
    mapping(uint256 => address) assetToOwner;

    modifier onlyAdmin() {
        require(msg.sender == admin, "Caller must be admin");
        _;
    }

    event updatedValuation(
        address assetCollection,
        uint256 nftId,
        uint256 valuation
    );
    event _stakeNft(
        address assetCollection,
        address owner,
        address vault,
        uint256 nftId
    );
    event _redeemNft(
        address assetCollection,
        address owner,
        address vault,
        uint256 nftId
    );

    constructor(
        address _assetToken,
        address _assetCollection,
        address _admin
    ) {
        assetToken = _assetToken;
        assetCollection = _assetCollection;
        admin = _admin;
    }

    function updateValuation(uint256 nftId, uint256 value) public onlyAdmin {
        _updateValuation(nftId, value);
    }

    function _updateValuation(uint256 nftId, uint256 value) internal {
        vaultCurrentValuation =
            vaultCurrentValuation -
            AssetValuation[nftId] +
            value;
        AssetValuation[nftId] = value;
        emit updatedValuation(assetCollection, nftId, value);
    }

    function intitalStake(
        uint256[] calldata nftIds,
        uint256[] calldata weights,
        uint256[] calldata valuations
    ) public {
        uint256 totalSupply = IERC20(assetToken).totalSupply();
        address caller = msg.sender;
        require(totalSupply == 0, "callled only for initial FMV");
        require(
            nftIds.length == weights.length &&
                weights.length == valuations.length,
            "length of all must be same"
        );
        uint256 totalWeight;
        uint256 totalValuation;
        for (uint256 i = 0; i < nftIds.length; i++) {
            totalWeight += weights[i];
            totalValuation += valuations[i];
            DynamicNFT(assetCollection).safeTransferFrom(
                caller,
                address(this),
                nftIds[i]
            );
            ownerToAsset[msg.sender] = nftIds[i];
            assetToOwner[nftIds[i]] = msg.sender;
            _updateValuation(nftIds[i], valuations[i]);
            emit _stakeNft(
                assetCollection,
                msg.sender,
                address(this),
                nftIds[i]
            );
        }

        uint256 requiredMint = (totalWeight * 10**12);
        initialFMV = (totalValuation * 10**24).div(requiredMint);
        GEMERC20(assetToken).Mint(caller, requiredMint);
    }

    function stakeNft(uint256[] calldata nftIds, uint256[] calldata valuations)
        public
    {
        uint256 _FMV = FMV();
        uint256 totalSupply = IERC20(assetToken).totalSupply();
        address caller = msg.sender;
        require(totalSupply != 0, "callled after one stake");
        require(
            nftIds.length == valuations.length,
            "length of all must be same"
        );
        uint256 totalValuation;
        for (uint256 i = 0; i < nftIds.length; i++) {
            totalValuation += valuations[i];
            DynamicNFT(assetCollection).safeTransferFrom(
                caller,
                address(this),
                nftIds[i]
            );
            ownerToAsset[msg.sender] = nftIds[i];
            assetToOwner[nftIds[i]] = msg.sender;
            _updateValuation(nftIds[i], valuations[i]);
            emit _stakeNft(
                assetCollection,
                msg.sender,
                address(this),
                nftIds[i]
            );
        }
        uint256 mintToken = (totalValuation * 10**24).div(_FMV);
        GEMERC20(assetToken).Mint(caller, mintToken);
    }

    function redeemNft(uint256 nftId) public {
        address caller = msg.sender;
        uint256 calculatedToken = (AssetValuation[nftId] * 10**24).div(FMV());
        require(
            IERC20(assetToken).balanceOf(caller) >= calculatedToken,
            "not Enough Token"
        );

        DynamicNFT(assetCollection).safeTransferFrom(
            address(this),
            caller,
            nftId
        );

        GEMERC20(assetToken).Burn(caller, calculatedToken);

        vaultCurrentValuation = vaultCurrentValuation - AssetValuation[nftId];

        if (GEMERC20(assetToken).totalSupply() == 0) {
            initialFMV = 0;
        }

        delete AssetValuation[nftId];

        delete ownerToAsset[assetToOwner[nftId]];

        delete assetToOwner[nftId];

        emit _redeemNft(assetCollection, msg.sender, address(this), nftId);
    }

    function annualInflationMinting() public onlyAdmin {
        uint256 yearInSecond = 365 * 24 * 3600;
        require(
            initialTime + yearInSecond >= block.timestamp,
            "within inflation time"
        );
        require(
            (75 * initialFMV) / 1000 >= FMV(),
            "not meet inflamation condition"
        );
        uint256 inflationToken = (FMV() * 10**12) / 100;
        GEMERC20(assetToken).Mint(admin, inflationToken);
        initialTime = block.timestamp;
        initialFMV = FMV();
    }

    function FMV() public view returns (uint256) {
        uint256 _FMV;
        uint256 totalSupply = IERC20(assetToken).totalSupply();
        if (totalSupply != 0) {
            _FMV = (vaultCurrentValuation * 10**24) / totalSupply;
        }

        return _FMV;
    }

    function getToken(uint256[] calldata assetvaluation)
        public
        view
        returns (uint256)
    {
        uint256 getValuation;
        for (uint8 i = 0; i < assetvaluation.length; i++) {
            getValuation += assetvaluation[i];
        }
        uint256 _getToken = getValuation.div(FMV());
        return _getToken;
    }

    function onERC721Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*tokenId*/
        bytes calldata /*data*/
    ) external pure override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
