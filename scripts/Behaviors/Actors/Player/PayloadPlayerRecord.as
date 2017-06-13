class PayloadPlayerRecord : VersusPlayerRecord
{
	PlayerClass playerClass;

	PayloadPlayerRecord()
	{
		super();
	}

	void HandlePlayerClass()
	{
		print("Peer " + peer + " HandlePlayerClass(" + int(playerClass) + ")");
		if (playerClass == PlayerClass::Soldier)
		{
			// Nothing to do
		}
		else if (playerClass == PlayerClass::Medic)
		{
			if (local)
				AddWeapon("weapons/healgun.sval");
		}
	}
}
