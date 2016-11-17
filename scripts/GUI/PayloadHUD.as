class PayloadHUD : IWidgetHoster
{
	TextWidget@ m_wStatus;

	Widget@ m_wCheckpointsTemplate;
	Widget@ m_wCheckpoints;

	Widget@ m_wPayload;
	TextWidget@ m_wPayloadText;

	Widget@ m_wCheckpointAlert;
	TextWidget@ m_wCheckpointAlertText;

	PayloadHUD(GUIBuilder& in b)
	{
		LoadWidget(b, "gui/payload.gui");

		@m_wStatus = cast<TextWidget>(m_widget.GetWidgetById("status"));

		@m_wCheckpointsTemplate = m_widget.GetWidgetById("checkpoints-template");
		@m_wCheckpoints = m_widget.GetWidgetById("checkpoints");

		@m_wPayload = m_widget.GetWidgetById("payload");
		@m_wPayloadText = cast<TextWidget>(m_wPayload.GetWidgetById("text"));

		@m_wCheckpointAlert = m_widget.GetWidgetById("checkpoint-alert");
		@m_wCheckpointAlertText = cast<TextWidget>(m_wCheckpointAlert.GetWidgetById("text"));
	}

	void ReachedCheckpont()
	{
		if (m_wCheckpointAlert is null)
			return;

		m_wCheckpointAlert.FinishAnimations();
		m_wCheckpointAlert.m_visible = true;
		m_wCheckpointAlert.Animate(WidgetBoolAnimation("visible", false, 3000));

		if (m_wCheckpointAlertText is null)
			return;

		m_wCheckpointAlertText.SetText("Checkpoint reached!");
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
		{
			int tmLeft = max(0, gm.m_tmLimit - gm.m_tmLevel);
			m_wStatus.SetText(formatTime(ceil(tmLeft / 1000.0f), false));
		}

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

		int insideAttackers = gm.m_payload.AttackersInside();
		int insideDefenders = gm.m_payload.DefendersInside();

		m_wPayloadText.m_visible = true;
		if (insideAttackers > 0 && insideDefenders == 0)
		{
			string str = "";
			for (int i = 0; i < insideAttackers; i++)
				str += ">";
			m_wPayloadText.SetText(str);
		}
		else if (insideAttackers == 0 && insideDefenders > 0)
			m_wPayloadText.SetText("<");
		else if (insideAttackers > 0 && insideDefenders > 0)
			m_wPayloadText.SetText("Contested!");
		else
			m_wPayloadText.m_visible = false;
	}
}
