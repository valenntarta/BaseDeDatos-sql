

-- PUNTO 1Y2
CREATE TABLE Usuarios (
	IdUsuario INT NOT NULL IDENTITY(1,1),
    Dni VARCHAR(50) NOT NULL,
	Genero VARCHAR(1) NOT NULL,
    Nombre VARCHAR(50) NOT NULL,
    Apellido VARCHAR(50) NOT NULL,
    FechaNacimiento DATE NOT NULL,
	CantidadResueltas INT DEFAULT 0,
	CantidadNoResueltas INT DEFAULT 0,
	CONSTRAINT PK_Usuario PRIMARY KEY(IdUsuario),
	CONSTRAINT CK_generoUsuario CHECK (genero IN ('M', 'F', 'O')),
	CONSTRAINT UQ_Dni UNIQUE(Dni),
	);

CREATE TABLE TipoInfraccion (
IdTipoInfraccion INT NOT NULL IDENTITY(1,1),
Tipo VARCHAR(50) NOT NULL,
CONSTRAINT PK_TipoInfraccion PRIMARY KEY (IdTipoInfraccion),
CONSTRAINT UQ_Tipo UNIQUE(Tipo),
);

CREATE TABLE Infracciones (
InfraccionNro INT NOT NULL IDENTITY(1000,1),
FechaInfraccion SMALLDATETIME NOT NULL,
Importe INT NOT NULL,
Vencimiento DATE NOT NULL,
Resolucion DATE,
ImporteAbonado INT,
IdUsuario INT NOT NULL,
IdTipoInfraccion INT NOT NULL,
CONSTRAINT PK_Infraccion PRIMARY KEY(InfraccionNro),
CONSTRAINT FK_Infraccion_Usuario FOREIGN KEY (IdUsuario) REFERENCES Usuarios(IdUsuario),
CONSTRAINT FK_TipoInfraccion FOREIGN KEY (IdTipoInfraccion) REFERENCES TipoInfraccion(IdTipoInfraccion),
);
GO

-- PUNTO 3

CREATE PROCEDURE InsertarTipoInfraccion
@Tipo VARCHAR(50) 
AS
	BEGIN
		BEGIN TRY 
		INSERT INTO TipoInfraccion(Tipo) VALUES (@Tipo)
		SELECT 'Agregado: ' + @Tipo  AS RESULTADO
		END TRY
		BEGIN CATCH 
		SELECT ERROR_MESSAGE() RESULTADO
		END CATCH
	END
GO 

CREATE PROCEDURE InsertarUsuario
 @Dni VARCHAR(50), 
 @Genero VARCHAR(1),
 @Nombre VARCHAR(50), 
 @Apellido VARCHAR(50),
 @FechaNacimiento DATE
AS
	BEGIN
		BEGIN TRY 
		INSERT INTO Usuarios(Dni, Nombre,Genero, Apellido, FechaNacimiento)
		 VALUES (@Dni,@Nombre,@Genero,@Apellido, @FechaNacimiento)
		SELECT 'Agregado '  + @Dni  AS RESULTADO
		END TRY
		BEGIN CATCH 
		SELECT ERROR_MESSAGE() RESULTADO
		END CATCH
	END
GO

CREATE PROCEDURE InsertarInfraccion
@FechaInfraccion SMALLDATETIME,
@Importe INT,
@Vencimiento DATE,
@IdUsuario INT, 
@IdTipoInfraccion INT

AS
	BEGIN
		BEGIN TRY 
			IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE IdUsuario = @IdUsuario)
				BEGIN
					SELECT 'La persona especificada no existe en la tabla Usuarios.' AS ERROR;
					RETURN;
				END
			INSERT INTO Infracciones(FechaInfraccion, Importe, Vencimiento, IdUsuario, IdTipoInfraccion)
			VALUES (@FechaInfraccion, @Importe, @Vencimiento, @IdUsuario, @IdTipoInfraccion)
			SELECT 'Infraccion agregada ' AS RESULTADO
			END TRY
		BEGIN CATCH 
			SELECT ERROR_MESSAGE() ERROR;
		END CATCH;
	END;
GO

CREATE TRIGGER ActualizarInfracciones ON Infracciones AFTER INSERT 
AS 
	BEGIN 
	UPDATE Usuarios SET CantidadNoResueltas = CantidadNoResueltas + 1
	FROM Usuarios 
	INNER JOIN inserted ON Usuarios.IdUsuario = inserted.IdUsuario
	END;	
GO

--PUNTO 4

CREATE PROCEDURE ActualizarInfraccionesAResueltas
    @resolucion DATE,
    @porcentajeDescuento INT,
    @porcentajeRecargo INT
AS
BEGIN
    BEGIN TRY
        IF (@porcentajeDescuento > 0 AND @porcentajeRecargo > 0) OR (@porcentajeDescuento < 0) OR (@porcentajeRecargo < 0)
        BEGIN
            SELECT 'Error: ambos deben ser positivos y uno de ellos debe ser cero.' AS ErrorMessage;
            RETURN;
        END;
		UPDATE Infracciones
        			SET Resolucion = CASE WHEN Resolucion IS NULL THEN @resolucion ELSE Resolucion END, 
					ImporteAbonado = CASE 
								WHEN @porcentajeDescuento != 0 THEN Importe - (Importe * (@porcentajeDescuento / 100))
								WHEN @porcentajeRecargo != 0 THEN Importe + (Importe * (@porcentajeRecargo / 100))
								ELSE Importe
								END
					WHERE Resolucion IS NULL
					SELECT 'Actualización exitosa' AS Resultado;
    END TRY
    BEGIN CATCH
        SELECT ERROR_MESSAGE() AS ERROR;
    END CATCH;
END;

GO 

CREATE TRIGGER ActualizarCantidadInfraccionesUsuario
ON Infracciones
AFTER UPDATE
AS
BEGIN
    UPDATE Usuarios
    SET CantidadNoResueltas = (SELECT COUNT(*) FROM Infracciones WHERE IdUsuario = Usuarios.IdUsuario AND Resolucion IS NULL)
    FROM Usuarios 
    INNER JOIN inserted ON Usuarios.IdUsuario = inserted.IdUsuario;
   
    UPDATE Usuarios
    SET CantidadResueltas = (SELECT COUNT(*) FROM Infracciones WHERE IdUsuario = Usuarios.IdUsuario AND Resolucion IS NOT NULL)
    FROM Usuarios 
    INNER JOIN inserted ON Usuarios.IdUsuario = inserted.IdUsuario;
END;
GO

--PUNTO 5

CREATE PROCEDURE ObtenerCantidadInfraccionesPorTipo
  @IdTipoInfraccion INT
AS
 BEGIN
  DECLARE @CantidadImpagas INT;
  DECLARE @CantidadPagas INT;

  SELECT @CantidadImpagas = COUNT(*)
  FROM Infracciones
  WHERE IdTipoInfraccion = @IdTipoInfraccion AND ImporteAbonado IS NULL;

  SELECT @CantidadPagas = COUNT(*)
  FROM Infracciones
  WHERE IdTipoInfraccion = @IdTipoInfraccion AND ImporteAbonado IS NOT NULL;

 SELECT @CantidadImpagas CantidadImpagas, @CantidadPagas CantidadPagas;
END;
GO

--PUNTO 6

CREATE PROCEDURE ObtenerImporteAdeudadoVencido
AS
BEGIN
  SELECT U.IdUsuario, SUM(I.Importe - ISNULL(I.ImporteAbonado, 0)) AS ImporteAdeudado
  FROM Infracciones I
  INNER JOIN Usuarios U ON U.IdUsuario = I.IdUsuario
  WHERE I.Vencimiento < GETDATE() AND I.Resolucion IS NULL
  GROUP BY U.IdUsuario;
END;
GO

--PUNTO 7
CREATE PROCEDURE EliminarPersona
  @IdUsuario INT
AS
	BEGIN
		BEGIN TRY
			IF NOT EXISTS (SELECT 1 FROM Usuarios WHERE IdUsuario = @IdUsuario)
			 BEGIN
				SELECT'No se encontro a la persona' AS NoExistePersona;
				RETURN;
			END;
			IF EXISTS (SELECT 1 FROM Infracciones WHERE IdUsuario = @IdUsuario)
				BEGIN
					SELECT 'La persona tiene infracciones. No se puede eliminar' AS PersonaConInfraccines ;
					RETURN;
				END;
			DELETE FROM Usuarios WHERE IdUsuario = @IdUsuario;
			SELECT (@IdUsuario) AS PERSONA_ELIMINADA;
		END TRY
		BEGIN CATCH 
			SELECT ERROR_MESSAGE() AS ERROR;
		END CATCH;
END;
GO

-- PUNTO 8
CREATE PROCEDURE EliminarInfraccion
    @InfraccionNro INT
AS
	BEGIN
		BEGIN TRY
		DECLARE @DniPersona VARCHAR(50);
			IF NOT EXISTS (SELECT 1 FROM Infracciones WHERE InfraccionNro = @InfraccionNro)
				BEGIN
					SELECT 'La infraccion no existe' AS NoExisteInfraccion;
					RETURN;
				END;
			IF EXISTS(SELECT 1 FROM Infracciones WHERE InfraccionNro = @InfraccionNro AND Resolucion IS NOT NULL)
				BEGIN
					SELECT 'La infraccion ya esta resuelta' AS NoExisteInfraccion;
					RETURN;
				END;
			BEGIN
				SELECT @DniPersona = U.Dni
				FROM Infracciones I
				INNER JOIN Usuarios U ON I.IdUsuario = U.IdUsuario
				WHERE I.InfraccionNro = @InfraccionNro;
				DELETE FROM Infracciones WHERE InfraccionNro = @InfraccionNro;
				UPDATE Usuarios
				SET CantidadNoResueltas = CantidadNoResueltas - 1
				WHERE Dni = @DniPersona
			END
		SELECT @DniPersona AS DniPersona;
		END TRY
		BEGIN CATCH 
			SELECT ERROR_MESSAGE() AS ERROR;
		END CATCH;
END;
GO

CREATE TRIGGER ActualizarCantidadNoResueltas ON Infracciones
AFTER DELETE
AS
BEGIN
    DECLARE @IdUsuario INT
    DECLARE @InfraccionNro INT

    SELECT @InfraccionNro = InfraccionNro FROM DELETED
    SELECT @IdUsuario = IdUsuario FROM Infracciones WHERE InfraccionNro = @InfraccionNro

    UPDATE Usuarios SET CantidadNoResueltas = CantidadNoResueltas - 1 WHERE IdUsuario = @IdUsuario
END
GO

--PUNTO 9
CREATE VIEW VISTA 
AS
SELECT U.DNI, TI.Tipo AS TipoInfraccion, COUNT(*) AS CantidadInfracciones
FROM Usuarios U
JOIN Infracciones I ON U.IdUsuario = I.IdUsuario
JOIN TipoInfraccion TI ON I.IdTipoInfraccion = TI.IdTipoInfraccion
WHERE I.Resolucion IS NULL
GROUP BY U.DNI, TI.Tipo;

GO

--PRUEBAS 
EXEC InsertarTipoInfraccion 'PROHIBIDO ESTACIONAR';
EXEC InsertarTipoInfraccion 'SEMAFORO ROJO';
EXEC InsertarTipoInfraccion 'EXCESO DE VELOCIDAD';

SELECT * FROM TipoInfraccion
ORDER BY IdTipoInfraccion;

GO 

EXEC InsertarUsuario '35000000' ,'M',  'Lio', 'Messi', '1987-06-24';
EXEC InsertarUsuario '39000000' ,'M',  'Emiliano', 'Martinez', '1982-09-02';
EXEC InsertarUsuario '38000000' ,'F',  'Paula', 'Paretto', '1986-01-15';
EXEC InsertarUsuario '36000000' ,'F',  'Wanda', 'Nara', '1986-12-09';
EXEC InsertarUsuario '40000000' ,'M',  'Julian', 'Alvarez', '2000-01-31';


SELECT * FROM Usuarios
ORDER BY IdUsuario;
GO 

EXEC InsertarInfraccion '2022-12-20 12:00', 5000,  '2023/01/15', 8, 1;
EXEC InsertarInfraccion '2022-12-24 13:18', 15000,  '2023/01/20', 8, 3;
EXEC InsertarInfraccion '2022-12-25 13:18', 15000,  '2023/01/20', 9, 3;
EXEC InsertarInfraccion '2022-11-26 13:28', 15000,  '2023/10/20', 10, 2;

EXEC ActualizarInfraccionesAResueltas '2023/10/29', 0, 10;

SELECT * FROM Infracciones;

SELECT * FROM VISTA;

EXEC ObtenerCantidadInfraccionesPorTipo 1

EXEC ObtenerImporteAdeudadoVencido 

EXEC EliminarPersona 11

EXEC EliminarInfraccion 1016

