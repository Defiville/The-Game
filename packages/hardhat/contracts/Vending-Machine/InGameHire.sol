//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

import "./library/math/SafeMath.sol";
import "./library/token/ERC20/SafeERC20.sol";

contract InGameHire {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    struct Hire {
        address creator;
        address user;
        address token;
        uint256 amount;
        uint256 startDate;
        uint256 duration;
        uint256 redeemed;
        bool valid;
    }

    mapping (uint256 => Hire) public hires;
    uint256 nextHireId;
    address public constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event HireSomeone(
        address user, 
        address tokens, 
        uint256 amounts, 
        uint256 startDate, 
        uint256 duration
    );
    event FireSomeone(uint256 hireId, uint256 payBack);
    event HireConcluded(uint256 hireId, uint256 amountClaimed);

    function hireUser(
        address _user, 
        address _token, 
        uint256 _amount, 
        uint256 _startDate, 
        uint256 _duration
    ) external payable {
        _hireUser(_user, _token, _amount, _startDate, _duration);
    }

    function _hireUser(
        address _user, 
        address _token, 
        uint256 _amount,
        uint256 _startDate,
        uint256 _duration
        ) internal {
            require(_startDate >= block.timestamp);
            Hire memory hire = Hire(
                msg.sender, 
                _user, 
                _token, 
                _amount, 
                _startDate, 
                _duration,
                0,
                true
            );

            hires[nextHireId] = hire;
            nextHireId = nextHireId + 1;

            if (hire.token == NATIVE) {
                require(_amount == msg.value, 'Wrong amount');
            } else {
                _receiveToken(_token, _amount);  
            }

            emit HireSomeone(_user, _token, _amount, _startDate, _duration);
    }

    function fireSomeone(uint256 _hireId) external {
        Hire storage hire = hires[_hireId];
        require(msg.sender == hire.creator, 'Only the creator');
        require(hire.valid, 'Not valid');

        uint256 amountRedeemable = redeemable(_hireId);
        uint256 amountLeft = hire.amount.sub(amountRedeemable).sub(hire.redeemed);
        hire.valid = false;

        if (hire.token == NATIVE) {
           payable(msg.sender).transfer(amountLeft); 
        } else {
          _sendtoken(hire.token, amountLeft, msg.sender);  
        }
    }

    function redeemPay(uint256 _hireId, uint256 _amount) external {
        Hire storage hire = hires[_hireId];
        require(msg.sender == hire.user);
        require(redeemable(_hireId) >= _amount);

        hire.redeemed = hire.redeemed.add(_amount);

        if (hire.redeemed == hire.amount) {
            emit HireConcluded(_hireId, hire.redeemed);
            hire.valid = false;
        }

        if (hire.token == NATIVE) {
            payable(msg.sender).transfer(_amount);
        } else {
          _sendtoken(hire.token, _amount, hire.user);  
        }
    }

    function _receiveToken(address _token, uint256 _amount) internal {
        uint256 amountBefore = IERC20(_token).balanceOf(address(this)); 
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        uint256 amountAfter = IERC20(_token).balanceOf(address(this));
        require (amountAfter.sub(amountBefore) == _amount, 'Wrong amount received');
    }

    function _sendtoken(address _token, uint256 _amount, address recipient) internal {
        uint256 amountBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(recipient, _amount);
        uint256 amountAfter = IERC20(_token).balanceOf(address(this));
        require(amountBefore.sub(amountAfter) == _amount, 'Wrong amount sent');
    }

    function redeemable(uint256 _hireId) public view returns(uint256) {
        Hire memory hire = hires[_hireId];
        
        if (!hire.valid) {
            return 0;
        }
        if (hire.startDate >= block.timestamp) {
            return 0;
        }
        if (hire.redeemed >= hire.amount) {
            return 0;
        }

        uint256 endDate = hire.startDate.add(hire.duration);
        uint256 maxRedeem;

        if (block.timestamp >= endDate) {
            maxRedeem = hire.amount;
        } else {
            uint256 timePassed = block.timestamp.sub(hire.startDate);
            uint256 tokenPerSecond = hire.amount.div(hire.duration);
            maxRedeem = timePassed.mul(tokenPerSecond);
        }

        return maxRedeem.sub(hire.redeemed);
    }
}