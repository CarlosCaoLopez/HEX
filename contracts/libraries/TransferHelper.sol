// SPDX-License-Identifier: MIT
pragma solidity=0.8.17;

library TransferHelper{
    function safeTransferFrom(
        address token,
        address from,
        address to,
        uint256 value
    ) internal {
        
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value)); /* Call de thansferFrom ERC20 token fuction (which selector is 0x23b872dd)*/
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            'TransferHelper::transferFrom: transferFrom failed'
        );
    }
}