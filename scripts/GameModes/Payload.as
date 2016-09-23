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

	int m_nodeCount;
	int m_nodeCurrent;

	Payload(Scene@ scene)
	{
		super(scene);
	}

	void UpdateFrame(int ms, GameInput& gameInput, MenuInput& menuInput) override
	{
		TeamVersusGameMode::UpdateFrame(ms, gameInput, menuInput);

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

	void Start(uint8 peer, SValue@ save, StartMode sMode) override
	{
		TeamVersusGameMode::Start(peer, save, sMode);

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

		UnitPtr unitNode = unitFirstNode;
		while (unitNode.IsValid())
		{
			auto node = cast<WorldScript::PayloadNode>(unitNode.GetScriptBehavior());
			if (node is null)
				break;

			m_nodeCount++;
			unitNode = node.NextNode.FetchFirst();

			@node.m_prevNode = prevNode;
			@node.m_nextNode = cast<WorldScript::PayloadNode>(unitNode.GetScriptBehavior());
		}
	}
}
