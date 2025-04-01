
actor {
  
  let ledger_canister = actor("bkyz2-fmaaa-aaaaa-qaaaq-cai") : actor {
    icrc1_balance_of : (account: {owner: Principal; subaccount: ?[Nat8]}) -> async Nat;
   
  };

  public shared query (msg) func whoami() : async Principal {
    msg.caller
  };

  public shared (msg) func checkBalance() : async Nat {
 
    let princ : Principal = msg.caller;
    
   
    let balance : Nat = await ledger_canister.icrc1_balance_of({
      owner = princ;
      subaccount = null;
    });
    
    return balance;
  };
  


}
