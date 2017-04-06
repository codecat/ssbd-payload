array<WorldScript::PayloadBeginTrigger@> g_payloadBeginTriggers;
array<WorldScript::PayloadTeamForcefield@> g_teamForceFields;

[GameMode]
class Payload : TeamVersusGameMode
{
	[Editable]
	UnitFeed PayloadUnit;

	[Editable]
	UnitFeed FirstNode;

	[Editable default=10]
	int PrepareTime;

	[Editable default=300]
	int TimeLimit;

	[Editable default=90]
	int TimeAddCheckpoint;

	[Editable default=2]
	float TimeOvertime;

	PayloadBehavior@ m_payload;

	int m_tmStarting;
	int m_tmStarted;
	int m_tmLimitCustom;
	int m_tmOvertime;
	int m_tmInOvertime;

	PayloadHUD@ m_payloadHUD;

	Payload(Scene@ scene)
	{
		super(scene);

		m_tmRespawnCountdown = 5000;

		ButtonWidget@ wJoin0 = cast<ButtonWidget>(m_switchTeam.m_widget.GetWidgetById("join_0"));
		if (wJoin0 !is null)
			wJoin0.SetText("Defenders");

		ButtonWidget@ wJoin1 = cast<ButtonWidget>(m_switchTeam.m_widget.GetWidgetById("join_1"));
		if (wJoin1 !is null)
			wJoin1.SetText("Attackers");

		@m_payloadHUD = PayloadHUD(m_guiBuilder);
	}

	void UpdateFrame(int ms, GameInput& gameInput, MenuInput& menuInput) override
	{
		TeamVersusGameMode::UpdateFrame(ms, gameInput, menuInput);

		m_payloadHUD.Update(ms);

		if (Network::IsServer())
		{
			uint64 tmNow = CurrPlaytimeLevel();

			if (m_tmStarting == 0)
			{
				if (GetPlayersInTeam(0) > 0 && GetPlayersInTeam(1) > 0)
				{
					m_tmStarting = tmNow;
					(Network::Message("GameStarting") << m_tmStarting).SendToAll();
				}
			}

			if (m_tmStarting > 0 && m_tmStarted == 0 && tmNow - m_tmStarting > PrepareTime * 1000)
			{
				m_tmStarted = tmNow;
				(Network::Message("GameStarted") << m_tmStarted).SendToAll();

				for (uint i = 0; i < g_payloadBeginTriggers.length(); i++)
				{
					WorldScript@ ws = WorldScript::GetWorldScript(g_scene, g_payloadBeginTriggers[i]);
					ws.Execute();
				}
			}
		}

		if (!m_ended && m_tmStarted > 0)
			CheckTimeReached(ms);
	}

	void CheckTimeReached(int dt)
	{
		// Check if time limit is not reached yet
		if (m_tmLimitCustom - (CurrPlaytimeLevel() - m_tmStarted) > 0)
		{
			// Don't need to continue checking
			m_tmOvertime = 0;
			m_tmInOvertime = 0;
			return;
		}

		// Count how long we're in overtime for later time limit fixing when we reach a checkpoint
		if (m_tmOvertime > 0)
			m_tmInOvertime += dt;

		// Check if there are any attackers still inside
		if (m_payload.AttackersInside() > 0)
		{
			// We have overtime
			m_tmOvertime = int(TimeOvertime * 1000);
			return;
		}

		// If we have overtime
		if (m_tmOvertime > 0)
		{
			// Decrease timer
			m_tmOvertime -= dt;
			if (m_tmOvertime <= 0)
			{
				// Overtime countdown reached, time limit reached
				TimeReached();
			}
		}
		else
		{
			// No overtime, so time limit is reached
			TimeReached();
		}
	}

	void TimeReached()
	{
		if (!Network::IsServer())
			return;

		(Network::Message("TimeReached")).SendToAll();
		SetWinner(false);
	}

	void SetWinner(bool attackers)
	{
		if (attackers)
			print("Attackers win!");
		else
			print("Defenders win!");

		m_payloadHUD.Winner(attackers);
		EndMatch();
	}

	void RenderFrame(int idt, SpriteBatch& sb) override
	{
		m_payloadHUD.Draw(sb, idt);

		TeamVersusGameMode::RenderFrame(idt, sb);
	}

	void Start(uint8 peer, SValue@ save, StartMode sMode) override
	{
		TeamVersusGameMode::Start(peer, save, sMode);

		m_tmLimit = 0; // infinite time limit as far as VersusGameMode is concerned
		m_tmLimitCustom = TimeLimit * 1000; // 5 minutes by default

		@m_payload = cast<PayloadBehavior>(PayloadUnit.FetchFirst().GetScriptBehavior());

		UnitPtr unitFirstNode = FirstNode.FetchFirst();
		if (unitFirstNode.IsValid())
		{
			auto node = cast<WorldScript::PayloadNode>(unitFirstNode.GetScriptBehavior());
			if (node !is null)
				@m_payload.m_targetNode = node;
			else
				PrintError("First target node is not a PayloadNode script!");
		}
		else
			PrintError("First target node was not set!");

		WorldScript::PayloadNode@ prevNode;

		float totalDistance = 0.0f;

		UnitPtr unitNode = unitFirstNode;
		while (unitNode.IsValid())
		{
			auto node = cast<WorldScript::PayloadNode>(unitNode.GetScriptBehavior());
			if (node is null)
				break;

			unitNode = node.NextNode.FetchFirst();

			@node.m_prevNode = prevNode;
			@node.m_nextNode = cast<WorldScript::PayloadNode>(unitNode.GetScriptBehavior());

			if (prevNode !is null)
				totalDistance += dist(prevNode.Position, node.Position);

			@prevNode = node;
		}

		float currDistance = 0.0f;

		auto distNode = cast<WorldScript::PayloadNode>(unitFirstNode.GetScriptBehavior());
		while (distNode !is null)
		{
			if (distNode.m_prevNode is null)
				distNode.m_locationFactor = 0.0f;
			else
			{
				currDistance += dist(distNode.m_prevNode.Position, distNode.Position);
				distNode.m_locationFactor = currDistance / totalDistance;
			}

			@distNode = distNode.m_nextNode;
		}

		m_payloadHUD.AddCheckpoints();
	}

	void SpawnPlayer(int i, vec2 pos = vec2(), int unitId = 0, uint team = 0) override
	{
		TeamVersusGameMode::SpawnPlayer(i, pos, unitId, team);

		if (!g_players[i].local)
			return;

		bool localAttackers = (team == HashString("player_1"));
		for (uint j = 0; j < g_teamForceFields.length(); j++)
		{
			bool hasCollision = (localAttackers != g_teamForceFields[j].Attackers);

			auto units = g_teamForceFields[j].Units.FetchAll();
			for (uint k = 0; k < units.length(); k++)
			{
				PhysicsBody@ body = units[k].GetPhysicsBody();
				if (body is null)
				{
					PrintError("PhysicsBody for unit " + units[k].GetDebugName() + "is null");
					continue;
				}
				body.SetActive(hasCollision);
			}
		}
	}
}
