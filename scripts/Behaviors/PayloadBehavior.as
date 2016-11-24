class PayloadBehavior
{
	UnitPtr m_unit;

	PhysicsBody@ m_body;

	int m_radius;
	int m_queryTime;

	AnimString@ m_animIdle;
	AnimString@ m_animWalk;

	float m_speedForward;
	float m_speedBackward;

	array<PlayerBase@> m_playersInside;

	WorldScript::PayloadNode@ m_prevNode;
	WorldScript::PayloadNode@ m_targetNode;

	float m_dir;

	PayloadBehavior(UnitPtr unit, SValue& params)
	{
		m_unit = unit;

		@m_body = m_unit.GetPhysicsBody();

		m_radius = GetParamInt(unit, params, "radius");

		@m_animIdle = AnimString(GetParamString(unit, params, "anim-idle"));
		@m_animWalk = AnimString(GetParamString(unit, params, "anim-walk"));

		m_speedForward = GetParamFloat(unit, params, "speed-forward");
		m_speedBackward = GetParamFloat(unit, params, "speed-backward");
	}

	int TeamInside(uint team)
	{
		int ret = 0;
		for (uint i = 0; i < m_playersInside.length(); i++)
		{
			if (m_playersInside[i].m_record.team == team)
				ret++;
		}
		return ret;
	}

	int TeamTotal(uint team)
	{
		int ret = 0;
		for (uint i = 0; i < g_players.length(); i++)
		{
			if (g_players[i].team == team)
				ret++;
		}
		return ret;
	}

	int AttackersInside()
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		if (gm.m_tmStarted == 0)
			return 0;
		return TeamInside(HashString("player_1"));
	}

	int AttackersTotal()
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		if (gm.m_tmStarted == 0)
			return 0;
		return TeamTotal(HashString("player_1"));
	}

	int DefendersInside()
	{
		return TeamInside(HashString("player_0"));
	}

	int DefendersTotal()
	{
		return TeamTotal(HashString("player_0"));
	}

	void CheckpointReached(UnitPtr node)
	{
		Payload@ gm = cast<Payload>(g_gameMode);
		gm.m_payloadHUD.ReachedCheckpont();

		if (gm.m_tmOvertime > 0)
			gm.m_tmLimit += gm.m_tmInOvertime;
		gm.m_tmLimit += gm.TimeAddCheckpoint * 1000;
	}

	void Update(int dt)
	{
		if (m_targetNode is null)
		{
			m_body.SetStatic(true);
			m_body.SetLinearVelocity(vec2());
			return;
		}

		if (m_queryTime <= 0)
		{
			array<UnitPtr>@ arrRange = g_scene.QueryCircle(xy(m_unit.GetPosition()), m_radius, ~0, RaycastType::Any);
			m_playersInside.removeRange(0, m_playersInside.length());
			for (uint i = 0; i < arrRange.length(); i++)
			{
				PlayerBase@ ply = cast<PlayerBase>(arrRange[i].GetScriptBehavior());
				if (ply is null)
					continue;

				m_playersInside.insertLast(ply);
			}
			m_queryTime = 100;
		}
		else
			m_queryTime -= dt;

		if (Network::IsServer())
		{
			int attackers = AttackersInside();
			int defenders = DefendersInside();

			float moveSpeed = 0.0f;
			bool backward = false;

			if (attackers > 0)
			{
				if (defenders == 0)
					moveSpeed = (attackers / float(AttackersTotal())) * m_speedForward;
				else
					moveSpeed = 0;
			}
			else if (defenders > 0)
			{
				moveSpeed = m_speedBackward;
				backward = true;
			}
			else
				moveSpeed = 0;

			WorldScript::PayloadNode@ target;

			if (moveSpeed > 0)
			{
				if (!backward)
					@target = m_targetNode;
				else if (backward)
					@target = m_prevNode;
			}

			vec2 newVelocity;

			if (target !is null)
			{
				float distStop = 4.0f;
				if (moveSpeed > 0 && distsq(target.Position, m_unit.GetPosition()) <= distStop * distStop)
				{
					if (backward)
					{
						if (m_prevNode.Checkpoint)
							moveSpeed = 0;
						else
						{
							@m_targetNode = m_prevNode;
							@m_prevNode = target.m_prevNode;

							UnitPtr unitTarget = WorldScript::GetWorldScript(g_scene, m_targetNode).GetUnit();
							UnitPtr unitPrev;
							if (m_prevNode !is null)
								unitPrev = WorldScript::GetWorldScript(g_scene, m_prevNode).GetUnit();

							(Network::Message("NewTargetNode") << unitTarget << unitPrev).SendToAll();
						}
					}
					else
					{
						WorldScript@ ws = WorldScript::GetWorldScript(g_scene, target);
						if (ws !is null)
							ws.Execute();

						if (target.m_nextNode is null)
						{
							(Network::Message("FinishReached")).SendToAll();

							Payload@ gm = cast<Payload>(g_gameMode);
							gm.SetWinner(true);

							@m_targetNode = null;
							moveSpeed = 0;
						}
						else
						{
							if (target is m_targetNode && target.Checkpoint)
							{
								//TODO: This should add time
								UnitPtr wsUnit = ws.GetUnit();
								(Network::Message("CheckpointReached") << m_unit << wsUnit).SendToAll();
								CheckpointReached(wsUnit);
							}
							@m_targetNode = target.m_nextNode;
							@m_prevNode = target;

							UnitPtr unitTarget = WorldScript::GetWorldScript(g_scene, m_targetNode).GetUnit();
							UnitPtr unitPrev = WorldScript::GetWorldScript(g_scene, m_prevNode).GetUnit();

							(Network::Message("NewTargetNode") << unitTarget << unitPrev).SendToAll();
						}
					}
				}

				vec2 dir = normalize(xy(target.Position) - xy(m_unit.GetPosition()));
				newVelocity = dir * moveSpeed;

				m_dir = atan(dir.y, dir.x);
			}

			m_body.SetStatic(lengthsq(newVelocity) == 0);
			m_body.SetLinearVelocity(newVelocity);
		}
		else
		{
			vec2 moveDir = m_unit.GetMoveDir();
			if (lengthsq(moveDir) > 0.01)
				m_dir = atan(moveDir.y, moveDir.x);

			m_body.SetStatic(true);
		}

		if (lengthsq(m_unit.GetMoveDir()) > 0.01)
			m_unit.SetUnitScene(m_animWalk.GetSceneName(m_dir), false);
		else
			m_unit.SetUnitScene(m_animIdle.GetSceneName(m_dir), false);
	}
}
