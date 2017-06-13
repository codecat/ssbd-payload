namespace PayloadHandler
{
	PlayerHusk@ GetPlayer(uint8 peer)
	{
		for (uint i = 0; i < g_players.length(); i++)
		{
			if (g_players[i].peer == peer)
			{
				if (g_players[i].actor is null)
					return null;

				if (g_players[i].local)
				{
					print("Player " + peer + " is not a husk on " + (Network::IsServer() ? "server" : "client"));
					return null;
				}

				return cast<PlayerHusk>(g_players[i].actor);
			}
		}

		return null;
	}

	PayloadPlayerRecord@ GetPlayerRecord(uint8 peer)
	{
		for (uint i = 0; i < g_players.length(); i++)
		{
			if (g_players[i].peer == peer)
				return cast<PayloadPlayerRecord>(g_players[i]);
		}

		return null;
	}

	void GameStarting(uint8 peer, int tm)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		gm.m_tmStarting = tm;
	}

	void GameStarted(uint8 peer, int tm)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
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

	void HealgunStart(uint8 peer, UnitPtr target)
	{
		PlayerHusk@ player = GetPlayer(peer);
		if (player is null)
			return;

		auto healgun = cast<PlayerHealgunHusk>(player.m_currWeapon);
		if (healgun is null)
		{
			PrintError("Player " + peer + " is not holding a healgun");
			return;
		}

		healgun.StartBeam(target);
	}

	void HealgunStop(uint8 peer, UnitPtr target)
	{
		PlayerHusk@ player = GetPlayer(peer);
		if (player is null)
			return;

		auto healgun = cast<PlayerHealgunHusk>(player.m_currWeapon);
		if (healgun is null)
		{
			PrintError("Player " + peer + " is not holding a healgun");
			return;
		}

		healgun.StopBeam();
	}

	void PayloadPlayerJoinTeam(uint8 peer, int teamIndex, int playerClassIndex)
	{
		if (!Network::IsServer())
			return;

		PlayerHandler::PlayerJoinTeam(peer, teamIndex);

		(Network::Message("PayloadPlayerClass") << playerClassIndex).SendToAll();
	}

	void PayloadPlayerClass(int peer, int playerClassIndex)
	{
		PayloadPlayerRecord@ record = GetPlayerRecord(peer);
		if (record is null)
		{
			PrintError("Peer " + peer + " not found");
			return;
		}

		record.playerClass = PlayerClass(playerClassIndex);

		auto gm = cast<Payload>(g_gameMode);
		gm.PlayerClassesUpdated();

		if (record.local)
			gm.HandleLocalPlayerClass(PlayerClass(playerClassIndex));
	}
}
