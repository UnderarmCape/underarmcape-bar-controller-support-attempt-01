# v0.8.4 General Command Insertion

RB is the single Insert modifier. RB+A and RB+X can insert active command confirmations when the controller has a real command context: build placement, a staged Tactical command, an active native command, or controller native targeting state.

Factory and lab focused build insertion still uses the factory insert path, while general command insertion goes through the normal command issuing helpers. Y is not a repair or insert modifier in this release.

RT+RB is not treated as Insert or append. The suppression path consumes that conflict and waits for both shoulders to return neutral before Build, Factory, Tactical, or Disassemble can claim RB again.
