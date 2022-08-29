// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.12;
import "../../interfaces/vaults/IPrivateVault.sol";
import { Constant,CalleeName } from "../../libraries/Constant.sol";
import "../../interfaces/validator/IValidator.sol";

contract PrivateVault is IPrivateVaultHub {
    address private signer;
    address private validator;
    address public caller;

    address private permissionLib;
    // Each vault can only participate in the mint seed behavior once
    bool public minted;

    //Used to determine whether a label already exists
    mapping(address => bool) private labelExist;

    // Used to indicate where a label is stored
    mapping(uint64 => address) private labels;

    // The mapping relationship between the hash value used to indicate the label and the true value of the label
    mapping(address => string) private hashToLabel;

    // Used to store real encrypted data
    mapping(address => string) private store;

    uint64 public total;

    bytes32 public DOMAIN_SEPARATOR;

    modifier auth() {
        require(msg.sender == caller, "vault:caller invalid");
        _;
    }

    constructor(
        address _signer,
        address _caller,
        address _validator,
        address _permissionLib
    ) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                Constant.PRIVATE_DOMAIN_TYPE_HASH,
                keccak256(bytes(Constant.PRIVATE_DOMAIN_NAME)),
                keccak256(bytes(Constant.PRIVATE_DOMAIN_VERSION)),
                chainId,
                address(this)
            )
        );

        signer = _signer;
        caller = _caller;
        validator = _validator;
        permissionLib = _permissionLib;
        total = 0;
        minted = false;
    }

    //cryptoLabel is encrypt message from Label value
    function saveWithMinting(
        string memory data,
        string memory cryptoLabel,
        address labelHash
    ) external auth {
        require(minted == false, "vault:mint done");

        //label was unused
        require(labelExist[labelHash] == false, "vault:label exist");

        store[labelHash] = data;
        labels[total] = labelHash;
        hashToLabel[labelHash] = cryptoLabel;
        total++;
        labelExist[labelHash] = true;

        minted = true;
    }

    function saveWithMintingDirectly(
        string memory data,
        string memory cryptoLabel,
        address labelHash,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(minted == false, "vault:mint done");
        require(IValidator(validator).isValid(tx.origin) == true, "vault: validator unpass");
        (bool res, ) = permissionLib.staticcall(
            abi.encodeWithSelector(CalleeName.SAVE_WITH_MINTING_PERMIT, signer,
            data, cryptoLabel, labelHash, deadline, v, r, s, DOMAIN_SEPARATOR));
        require(res == true, "vault:mint ERROR");

        //label was unused
        require(labelExist[labelHash] == false, "vault:label exist");

        store[labelHash] = data;
        labels[total] = labelHash;
        hashToLabel[labelHash] = cryptoLabel;
        total++;
        labelExist[labelHash] = true;

        minted = true;
    }

    function saveWithoutMinting(
        string memory data,
        string memory cryptoLabel,
        address labelHash
    ) external auth {
        //label was unused
        require(labelExist[labelHash] == false, "vault:label exist");
        store[labelHash] = data;
        labels[total] = labelHash;
        hashToLabel[labelHash] = cryptoLabel;
        total++;
        labelExist[labelHash] = true;
    }

    function saveWithoutMintingDirectly(
        string memory data,
        string memory cryptoLabel,
        address labelHash,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(IValidator(validator).isValid(tx.origin) == true, "vault: validator unpass");
        (bool res, ) = permissionLib.staticcall(
            abi.encodeWithSelector(CalleeName.SAVE_WITHOUT_MINTING_PERMIT, signer,
            data, cryptoLabel, labelHash, deadline, v, r, s, DOMAIN_SEPARATOR));
        require(res == true, "vault:without ERROR");

        //label was unused
        require(labelExist[labelHash] == false, "vault:label exist");
        store[labelHash] = data;
        labels[total] = labelHash;
        hashToLabel[labelHash] = cryptoLabel;
        total++;
        labelExist[labelHash] = true;
    }

    function getPrivateDataByIndex(uint64 index) external view auth returns (string memory) {
        require(total > index, "vault:keys overflow");
        return store[labels[index]];
    }

    function getPrivateDataByIndexDirectly(
        uint64 index,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (string memory) {
        require(total > index, "vault:keys overflow");

        (bool res, ) = permissionLib.staticcall(
            abi.encodeWithSelector(CalleeName.GET_PRIVATE_DATA_BY_INDEX_PERMIT, signer,
            index, deadline, v, r, s, DOMAIN_SEPARATOR));
        require(res == true, "vault:index ERROR");

        return store[labels[index]];
    }

    function getPrivateDataByName(address name) external view auth returns (string memory) {
        require(labelExist[name] == true, "vault:label no exist");

        return store[name];
    }

    function getPrivateDataByNameDirectly(
        address name,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (string memory) {
        (bool res, ) = permissionLib.staticcall(
            abi.encodeWithSelector(CalleeName.GET_PRIVATE_DATA_BY_NAME_PERMIT, signer,
            name, deadline, v, r, s, DOMAIN_SEPARATOR));
        require(res == true, "vault:name ERROR");

        require(labelExist[name] == true, "vaule:label no exist");

        return store[name];
    }

    function labelName(uint64 index) external view auth returns (string memory) {
        require(index < total);
        return hashToLabel[labels[index]];
    }

    function labelNameDirectly(
        uint64 index,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (string memory) {
        require(index < total);
        (bool res, ) = permissionLib.staticcall(
            abi.encodeWithSelector(CalleeName.LABEL_NAME_PERMIT, signer,
            index, deadline, v, r, s, DOMAIN_SEPARATOR));
        require(res == true, "vault:lname ERROR");

        return hashToLabel[labels[index]];
    }

    function labelIsExist(address labelHash) external view auth returns (bool) {
        bool exist = labelExist[labelHash];
        return exist;
    }

    function labelIsExistDirectly(
        address labelHash,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external view returns (bool) {
        (bool res, ) = permissionLib.staticcall(
            abi.encodeWithSelector(CalleeName.LABEL_IS_EXIST_PERMIT, signer,
            labelHash, deadline, v, r, s, DOMAIN_SEPARATOR));
        require(res == true, "vault:exist ERROR");
        return labelExist[labelHash];
    }
}