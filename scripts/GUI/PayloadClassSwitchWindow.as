class PayloadClassSwitchWindow : IWidgetHoster
{
	bool m_visible = false;

	TeamVersusScore@ m_joinTeam;

	PayloadClassSwitchWindow(GUIBuilder@ b)
	{
		LoadWidget(b, "gui/class_switch.gui");
	}

	void JoinTeam(TeamVersusScore@ score, PlayerClass playerClass)
	{
		auto gm = cast<Payload>(g_gameMode);
		if (gm is null)
			return;

		if (Network::IsServer())
		{
			for (uint i = 0; i < g_players.length(); i++)
			{
				if (!g_players[i].local)
					continue;
				gm.MovePlayerInTeam(i, score);
				gm.HandleLocalPlayerClass(playerClass);
				(Network::Message("PayloadPlayerClass") << g_players[i].peer << int(playerClass)).SendToAll();
				break;
			}
		}
		else
			(Network::Message("PayloadPlayerJoinTeam") << score.m_index << int(playerClass)).SendToHost();

		Hide();
	}

	void Show()
	{
		if (m_visible)
			return;

		m_visible = true;

		Platform::PushCursor(Platform::CursorNormal);
		g_gameMode.ReplaceTopWidgetRoot(this);
	}

	void Hide()
	{
		if (!m_visible)
			return;

		m_visible = false;

		Platform::PopCursor();
		g_gameMode.ClearWidgetRoot();
	}

	void PlayerClassesUpdated()
	{
		Payload@ gm = cast<Payload>(g_gameMode);

		int numMedics = gm.GetPlayerClassCount(PlayerClass::Medic);

		auto wMedic = cast<ScalableSpriteButtonWidget>(m_widget.GetWidgetById("class-medic"));
		if (wMedic !is null)
			wMedic.m_enabled = (numMedics == 0);
	}

	void Draw(SpriteBatch& sb, int idt) override
	{
		if (!m_visible)
			return;

		IWidgetHoster::Draw(sb, idt);
	}

	void UpdateInput(vec2 origin, vec2 parentSz, vec3 mousePos) override
	{
		if (!m_visible)
			return;

		IWidgetHoster::UpdateInput(origin, parentSz, mousePos);
	}

	void OnFunc(Widget@ sender, string name) override
	{
		if (!m_visible)
			return;

		auto parse = name.split(" ");
		if (parse[0] == "class")
		{
			PlayerClass c = PlayerClass::Soldier;
			if (parse[1] == "medic")
				c = PlayerClass::Medic;
			JoinTeam(m_joinTeam, c);
		}

		IWidgetHoster::OnFunc(sender, name);
	}
}
