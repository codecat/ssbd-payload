class PayloadHUD : IWidgetHoster
{
	TextWidget@ m_wStatus;

	Widget@ m_wCheckpointsTemplate;
	Widget@ m_wCheckpoints;

	Widget@ m_wPayload;

	PayloadHUD(GUIBuilder& in b)
	{
		LoadWidget(b, "gui/payload.gui");

		@m_wStatus = cast<TextWidget>(m_widget.GetWidgetById("status"));

		@m_wCheckpointsTemplate = m_widget.GetWidgetById("checkpoints-template");
		@m_wCheckpoints = m_widget.GetWidgetById("checkpoints");

		@m_wPayload = m_widget.GetWidgetById("payload");
	}

	void AddCheckpoints()
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		if (gm is null)
			return;

		UnitPtr unitFirstNode = gm.FirstNode.FetchFirst();
		if (!unitFirstNode.IsValid())
			return;

		auto node = cast<WorldScript::PayloadNode>(unitFirstNode.GetScriptBehavior());
		while (node !is null)
		{
			if (node.Checkpoint || node.m_nextNode is null)
			{
				SpriteWidget@ wCheckpoint = cast<SpriteWidget>(m_wCheckpointsTemplate.Clone());
				wCheckpoint.m_id = "";
				wCheckpoint.m_visible = true;
				wCheckpoint.SetSprite("checkpoint-blue");
				wCheckpoint.m_offset.x = (node.m_locationFactor * m_wCheckpoints.m_width) - 3;
				m_wCheckpoints.AddChild(wCheckpoint);
			}

			@node = node.m_nextNode;
		}
	}

	void Update(int dt) override
	{
		IWidgetHoster::Update(dt);

		Payload@ gm = cast<Payload>(g_gameMode);
		if (gm is null)
			return;

		if (gm.m_tmStarted == 0)
			m_wStatus.SetText("Start in " + ceil(10 - gm.m_tmLevel / 1000));
		else
			m_wStatus.m_visible = false;

		float payloadFactor = 0.0f;

		auto nodePrev = gm.m_payload.m_prevNode;
		auto nodeTarget = gm.m_payload.m_targetNode;

		if (nodePrev !is null && nodeTarget !is null)
		{
			float distMax = dist(nodePrev.Position, nodeTarget.Position);
			float distCurrent = dist(gm.m_payload.m_unit.GetPosition(), nodeTarget.Position);
			float distFactor = 1 - distCurrent / distMax;

			payloadFactor = lerp(nodePrev.m_locationFactor, nodeTarget.m_locationFactor, distFactor);
		}

		m_wPayload.m_offset.x = (payloadFactor * m_wCheckpoints.m_width) - 2;
	}
}
