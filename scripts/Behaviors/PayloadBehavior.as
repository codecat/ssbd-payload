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
		return TeamInside(HashString("player_1"));
	}

	int AttackersTotal()
	{
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

	void Update(int dt)
	{
		if (m_targetNode is null)
		{
			m_body.SetLinearVelocity(vec2());
			return;
		}

		if (Network::IsServer())
		{
			if (m_queryTime <= 0)
			{
				array<UnitPtr>@ arrRange = g_scene.QueryCircle(xy(m_unit.GetPosition()), m_radius, ~0, RaycastType::Any);
				while (m_playersInside.length() > 0)
					m_playersInside.removeLast();
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
				else if (backward && m_prevNode !is null && !m_targetNode.Checkpoint)
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
						@m_targetNode = m_prevNode;
						@m_prevNode = target.m_prevNode;
					}
					else
					{
						WorldScript@ ws = WorldScript::GetWorldScript(g_scene, target);
						if (ws !is null)
							ws.Execute();

						if (target.m_nextNode is null)
						{
							print("Attackers win!");
							@m_targetNode = null;
							moveSpeed = 0;
						}
						else
						{
							@m_targetNode = target.m_nextNode;
							@m_prevNode = target;
						}
					}
				}

				vec2 dir = normalize(xy(target.Position) - xy(m_unit.GetPosition()));
				newVelocity = dir * moveSpeed;

				m_dir = atan(dir.y, dir.x);
			}

			m_body.SetLinearVelocity(newVelocity);
		}
		else
		{
			vec2 moveDir = m_unit.GetMoveDir();
			if (lengthsq(moveDir) > 0.01)
				m_dir = atan(moveDir.y, moveDir.x);
		}

		if (lengthsq(m_unit.GetMoveDir()) > 0.01)
			m_unit.SetUnitScene(m_animWalk.GetSceneName(m_dir), false);
		else
			m_unit.SetUnitScene(m_animIdle.GetSceneName(m_dir), false);
	}
}
