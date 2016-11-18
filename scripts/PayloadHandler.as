namespace PayloadHandler
{
	void CheckpointReached(uint8 peer, UnitPtr payload, UnitPtr node)
	{
		PayloadBehavior@ pl = cast<PayloadBehavior>(payload.GetScriptBehavior());
		if (pl is null)
		{
			PrintError("payload unit " + payload.GetId() + " is not a PayloadBehavior (" + payload.GetDebugName() + ")");
			return;
		}

		pl.CheckpointReached(node);
	}

	void FinishReached(uint8 peer)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		gm.SetWinner(true);
	}

	void TimeReached(uint8 peer)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		gm.SetWinner(false);
	}
}
