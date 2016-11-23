namespace PayloadHandler
{
	void GameStarting(uint8 peer, int tm)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		gm.m_tmLevel = tm;
		gm.m_tmStarting = tm;
	}

	void GameStarted(uint8 peer, int tm)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		gm.m_tmLevel = tm;
		gm.m_tmStarted = tm;
	}

	void NewTargetNode(uint8 peer, UnitPtr unitTarget, UnitPtr unitPrev)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		PayloadBehavior@ pl = gm.m_payload;
		if (pl is null)
		{
			PrintError("There is no payload.");
			return;
		}

		if (unitTarget.IsValid())
			@pl.m_targetNode = cast<WorldScript::PayloadNode>(unitTarget.GetScriptBehavior());
		if (unitPrev.IsValid())
			@pl.m_prevNode = cast<WorldScript::PayloadNode>(unitPrev.GetScriptBehavior());
	}

	void CheckpointReached(uint8 peer, UnitPtr payload, UnitPtr node)
	{
		PayloadBehavior@ pl = cast<PayloadBehavior>(payload.GetScriptBehavior());
		if (pl is null)
		{
			PrintError("Payload unit " + payload.GetId() + " is not a PayloadBehavior (" + payload.GetDebugName() + ")");
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
