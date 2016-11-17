array<WorldScript::PayloadBeginTrigger@> g_payloadBeginTriggers;

[GameMode]
class Payload : TeamVersusGameMode
{
	[Editable]
	UnitFeed PayloadUnit;

	[Editable]
	UnitFeed FirstNode;

	PayloadBehavior@ m_payload;

	int m_tmStarted;
	int m_tmLimit;

	PayloadHUD@ m_payloadHUD;

	Payload(Scene@ scene)
	{
		super(scene);

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

		if (m_tmStarted == 0 && m_tmLevel > 10000)
		{
			m_tmStarted = m_tmLevel;

			for (uint i = 0; i < g_payloadBeginTriggers.length(); i++)
			{
				WorldScript@ ws = WorldScript::GetWorldScript(g_scene, g_payloadBeginTriggers[i]);
				ws.Execute();
			}
		}
	}

	void RenderFrame(int idt, SpriteBatch& sb) override
	{
		m_payloadHUD.Draw(sb, idt);

		TeamVersusGameMode::RenderFrame(idt, sb);
	}

	void Start(uint8 peer, SValue@ save, StartMode sMode) override
	{
		TeamVersusGameMode::Start(peer, save, sMode);

		m_tmLimit = 5 * 60 * 1000; // 5 minutes

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
}
