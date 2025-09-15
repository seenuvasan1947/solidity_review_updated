## Balancer issues

(+) Missing calls to _updateTokenInRegistry leads to incorrect state of tokens in registry #1404
https://github.com/code-423n4/2024-04-noya-findings/issues/1404

In the BalancerConnector, unclaimed rewards are not included in the calculation of the connectors TVL #1402 
https://github.com/code-423n4/2024-04-noya-findings/issues/1402

A Vault can steal all funds from another Vault through the Registry's flash loan contract due to insufficient access control in Connector.sendTokensToTrustedAddress() #1327 
https://github.com/code-423n4/2024-04-noya-findings/issues/1327

BalancerConnector::_getPositionTVL is calculated incorrectly #1033 
https://github.com/code-423n4/2024-04-noya-findings/issues/1033

BalancerConnector has incorrect implementation of totalSupply, positionTVL and total TVL will be invalid #1021 
https://github.com/code-423n4/2024-04-noya-findings/issues/1021

In BalancerConnector, The protocol does not track the extra reward properly other than AURA reward #978 
https://github.com/code-423n4/2024-04-noya-findings/issues/978

Balancer flashloan contract can be DOSed completely by sending 1 wei to it #602 
https://github.com/code-423n4/2024-04-noya-findings/issues/602



