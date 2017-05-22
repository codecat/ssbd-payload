class PlayerHealgun : PlayerGun
{
	bool m_attackDown;
	float m_lastDmgMul;

	string m_holdFx;
	UnitPtr m_holdFxUnit;
	string m_hitFx;

	float m_beamRange;

	SoundEvent@ m_holdLoopSound;
	SoundEvent@ m_holdEndSound;
	SoundInstance@ m_holdLoopSoundI;

	array<IEffect@>@ m_hitEffects;

	UnitScene@ m_sceneMarkerGreen;
	UnitScene@ m_sceneMarkerRed;

	Actor@ m_hoverActor;
	float m_hoverDistance;
	bool m_hoverVisible;

	int m_tmHeal;
	int m_tmHealC;

	int m_healAmount;

	PlayerHealgun(UnitPtr owner, SValue& params)
	{
		super(owner, params);

		m_holdFx = GetParamString(owner, params, "beam-fx");

		m_beamRange = GetParamFloat(owner, params, "beam-range");

		@m_holdLoopSound = Resources::GetSoundEvent(GetParamString(owner, params, "hold-loop-snd", false));
		@m_holdEndSound = Resources::GetSoundEvent(GetParamString(owner, params, "hold-end-snd", false));

		m_hitFx = GetParamString(owner, params, "beam-hit-fx", false);
		@m_hitEffects = LoadEffects(owner, params, "beam-hit-");

		@m_sceneMarkerGreen = m_armsProd.GetUnitScene("marker-green");
		@m_sceneMarkerRed = m_armsProd.GetUnitScene("marker-red");

		m_tmHeal = GetParamInt(owner, params, "heal-time", false, 50);
		m_healAmount = GetParamInt(owner, params, "heal-amount", false, 5);
	}

	bool ActorActive()
	{
		return m_hoverActor !is null;
	}

	bool ActorHealable()
	{
		if (m_hoverActor is null)
			return false;

		if (!m_hoverVisible)
			return false;

		return m_hoverDistance < m_beamRange;
	}

	void Initialize(string path) override
	{
		PlayerGun::Initialize(path);
	}

	void Unequip() override
	{
		StopBeam();

		PlayerGun::Unequip();
	}

	void StartBeam(vec3 pos)
	{
		if (m_holdFxUnit.IsValid())
			StopBeam();

		dictionary ePs = { { 'angle', m_holdDir }, { 'length', m_holdLength } };
		m_holdFxUnit = PlayEffect(m_holdFx, xy(pos), ePs);
		auto behavior = cast<EffectBehavior>(m_holdFxUnit.GetScriptBehavior());
		behavior.m_looping = true;
	}

	void StopBeam()
	{
		if (!m_holdFxUnit.IsValid())
			return;

		if (!m_holdFxUnit.IsDestroyed())
			m_holdFxUnit.Destroy();
		m_holdFxUnit = UnitPtr();
	}

	void Update(int dt, vec2 dir, bool freezeControls) override
	{
		Player@ player = GetLocalPlayer();
		if (player is null)
			return;

		vec3 pos = player.m_unit.GetPosition();
		pos.y -= Tweak::PlayerCameraHeight;

		auto input = GetInput();

		if (!input.Attack.Down)
		{
			Actor@ closestActor = null;
			float closestDistance = 99999.0f;

			vec3 mousePos = ToWorldspace(input.MousePos);
			auto arrUnits = g_scene.QueryCircle(xy(mousePos), 40, ~0, RaycastType::Any, true);
			for (uint i = 0; i < arrUnits.length(); i++)
			{
				UnitPtr unit = arrUnits[i];

				Actor@ actor = cast<Actor>(unit.GetScriptBehavior());
				if (actor is null || actor is player)
					continue;

				float distance = dist(player.m_unit.GetPosition(), unit.GetPosition());
				if (distance > closestDistance)
					continue;

				@closestActor = actor;
				closestDistance = distance;
			}

			@m_hoverActor = closestActor;
		}

		vec2 playerPos = xy(pos);
		vec2 actorPos;

		if (m_hoverActor !is null)
		{
			actorPos = xy(m_hoverActor.m_unit.GetPosition());

			m_hoverDistance = dist(player.m_unit.GetPosition(), m_hoverActor.m_unit.GetPosition());

			m_hoverVisible = true;
			array<RaycastResult>@ res = g_scene.Raycast(playerPos, actorPos, ~0, RaycastType::Any);
			for (uint i = 0; i < res.length(); i++)
			{
				UnitPtr unit = res[i].FetchUnit(g_scene);
				IDamageTaker@ d = cast<IDamageTaker>(unit.GetScriptBehavior());
				if (d is null || d.Impenetrable())
				{
					m_hoverVisible = false;
					break;
				}
			}
		}

		vec2 actorDir = normalize(actorPos - playerPos);

		if (input.Attack.Pressed)
		{
			if (ActorHealable())
			{
				m_holdDir = m_holdDirNext = atan(actorDir.y, actorDir.x);
				m_holdLength = m_holdLengthNext = dist(playerPos, actorPos);

				StartBeam(pos);

				m_tmHealC = m_tmHeal;
			}
		}
		else if (input.Attack.Released)
			StopBeam();
		else if (input.Attack.Down && ActorActive())
		{
			m_holdDir = m_holdDirNext;
			m_holdLength = m_holdLengthNext;

			m_holdDirNext = atan(actorDir.y, actorDir.x);
			m_holdLengthNext = dist(playerPos, actorPos);

			// deal with 360 to 0 wrapping
			if (abs(m_holdDirNext - m_holdDir) > PI / 2.0)
				m_holdDir = m_holdDirNext;

			if (m_holdFxUnit.IsValid() && !m_holdFxUnit.IsDestroyed())
			{
				if (!ActorHealable())
					StopBeam();
			}
			else if (ActorHealable())
				StartBeam(pos);

			if (ActorHealable())
			{
				m_tmHealC -= dt;
				if (m_tmHealC <= 0)
				{
					m_tmHealC = m_tmHeal;
					m_hoverActor.Heal(m_healAmount);
				}
			}
		}

		PlayerGun::Update(dt, dir, freezeControls);
	}

	void PreRender(int idt) override
	{
		Player@ player = GetLocalPlayer();

		float mul = idt / 33.0;

		vec3 pos = player.m_unit.GetInterpolatedPosition(idt);
		if (m_holdFxUnit.IsValid() && !m_holdFxUnit.IsDestroyed())
		{
			pos.y -= Tweak::PlayerCameraHeight;
			m_holdFxUnit.SetPosition(pos.x, pos.y, pos.z);

			auto behavior = cast<EffectBehavior>(m_holdFxUnit.GetScriptBehavior());
			if (behavior !is null)
			{
				behavior.SetParam("angle", lerp(m_holdDir, m_holdDirNext, mul));
				behavior.SetParam("length", lerp(m_holdLength, m_holdLengthNext, mul));
			}
		}
	}

	void RenderMarkers(int idt, SpriteBatch& sb)
	{
		if (ActorActive())
		{
			vec3 uPos = m_hoverActor.m_unit.GetInterpolatedPosition(idt);
			vec2 pos = ToScreenspace(uPos) / g_gameMode.m_wndScale;

			UnitScene@ scene = m_sceneMarkerGreen;
			if (!ActorHealable())
				@scene = m_sceneMarkerRed;

			sb.DrawUnitScene(pos - vec2(16, 15), vec2(32, 31), scene, g_scene.GetTime());
		}
	}
}
