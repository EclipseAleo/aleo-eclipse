import token_registry.aleo;

program treasury.aleo {
  mapping balance: field => u128;
  async transition receive_funds(
    public token_id: field,
    public amount:   u128,
    public from:     address
  ) -> Future {
    let f: Future = token_registry.aleo/transfer_public(
      token_id, self.caller, amount
    );
    return finalize_receive(f, token_id, amount);
  }
  async function finalize_receive(
    f: Future,
    public token_id: field,
    public amount:   u128
  ) {
    f.await();
    let prev: u128 = balance.get_or_use(token_id, 0u128);
    balance.set(token_id, prev + amount);
  }
}
