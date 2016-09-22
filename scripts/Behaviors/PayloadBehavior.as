class PayloadBehavior
{
	UnitPtr m_unit;

	AnimString@ m_animIdle;
	AnimString@ m_animWalk;

	array<PlayerBase@> m_playersInside;

	PayloadBehavior(UnitPtr unit, SValue& params)
	{
		m_unit = unit;

		@m_animIdle = AnimString(GetParamString(unit, params, "anim-idle"));
		@m_animWalk = AnimString(GetParamString(unit, params, "anim-walk"));
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

	int AttackersInside()
	{
		return TeamInside(HashString("player_1"));
	}

	int DefendersInside()
	{
		return TeamInside(HashString("player_0"));
	}

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

	void Update(int dt)
	{
		int attackers = AttackersInside();
		int defenders = DefendersInside();

		if (attackers > 0)
		{
			if (defenders == 0)
				print(">>> " + attackers);
			else
				print("Contended!");
		}
		else if (defenders > 0)
			print("< 1");
		else
			print("idle");
	}
}
