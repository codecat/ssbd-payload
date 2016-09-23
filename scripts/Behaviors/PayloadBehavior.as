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

	/*
	void Collide(UnitPtr unit, vec2 pos, vec2 normal, Fixture@ fxSelf, Fixture@ fxOther)
	{
		PlayerBase@ ply = cast<PlayerBase>(unit.GetScriptBehavior());
		if (ply is null)
			return;

		if (!fxSelf.IsSensor() || fxOther.IsSensor())
			return;

		m_playersInside.insertLast(ply);
	}

	void EndCollision(UnitPtr unit, Fixture@ fxSelf, Fixture@ fxOther)
	{
		PlayerBase@ ply = cast<PlayerBase>(unit.GetScriptBehavior());
		if (ply is null)
			return;

		if (!fxSelf.IsSensor() || fxOther.IsSensor())
			return;

		int index = m_playersInside.findByRef(ply);
		if (index == -1)
		{
			PrintError("Leaving player not inside of payload collision");
			return;
		}

		m_playersInside.removeAt(index);
	}
	*/

	void Update(int dt)
	{
		if (m_targetNode is null)
			return;

		if (m_queryTime <= 0)
		{
			array<UnitPtr>@ arrRange = g_scene.QueryCircle(xy(m_unit.GetPosition()), m_radius, ~0, RaycastType::Any);
			print("------ in range: ------");
			for (uint i = 0; i < arrRange.length(); i++)
				print(i + ": " + arrRange[i].GetDebugName());
			m_queryTime = 100;
		}
		else
			m_queryTime -= dt;

		int attackers = AttackersInside();
		int defenders = DefendersInside();

		float moveSpeed = 0.0f;

		if (attackers > 0)
		{
			if (defenders == 0)
				moveSpeed = (attackers / float(AttackersTotal())) * m_speedForward;
			else
				moveSpeed = 0;
		}
		else if (defenders > 0)
			moveSpeed = m_speedBackward;
		else
			moveSpeed = 0;

		WorldScript::PayloadNode@ target;

		if (moveSpeed > 0)
			@target = m_targetNode;
		else if (moveSpeed < 0 && m_prevNode !is null && !m_targetNode.Checkpoint)
			@target = m_prevNode;

		vec2 newVelocity;

		if (target !is null)
		{
			float distStop = 4.0f;
			if (distsq(target.Position, m_unit.GetPosition()) <= distStop * distStop)
			{
				if (moveSpeed < 0)
				{
					@m_targetNode = m_prevNode;
					@m_prevNode = target.m_prevNode;
				}
				else if (moveSpeed > 0)
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

		if (length(newVelocity) > 0)
			m_unit.SetUnitScene(m_animWalk.GetSceneName(m_dir), false);
		else
			m_unit.SetUnitScene(m_animIdle.GetSceneName(m_dir), false);

		m_body.SetLinearVelocity(newVelocity);
	}
}
