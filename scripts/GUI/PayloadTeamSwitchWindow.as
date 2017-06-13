class PayloadTeamSwitchWindow : TeamSwitchWindow
{
	PayloadTeamSwitchWindow(GUIBuilder@ b)
	{
		super(b);
	}

	void JoinTeam(TeamVersusScore@ score) override
	{
		Hide();

		auto gm = cast<Payload>(g_gameMode);
		if (gm !is null)
		{
			@gm.m_switchClass.m_joinTeam = score;
			gm.m_switchClass.Show();
		}
	}
}
