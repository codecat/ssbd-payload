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
}
