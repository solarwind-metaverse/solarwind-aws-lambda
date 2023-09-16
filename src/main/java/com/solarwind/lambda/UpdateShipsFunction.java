package com.solarwind.lambda;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.LambdaLogger;
import com.amazonaws.services.lambda.runtime.RequestHandler;

record IntegerRecord(int x, int y, String message) {
}

// Handler value: example.HandlerInteger
public class UpdateShipsFunction {

  public String handleRequest(Context context) {

    String dbServer = System.getenv("DB_SERVER");
    String dbUrl = "jdbc:postgresql://" + dbServer + ":5432/solarwind";

    String dbUser = System.getenv("DB_USER");
    String dbPassword = System.getenv("DB_PASSWORD");
    
    int count = 0;

    try {

      Connection connection = DriverManager.getConnection(dbUrl, dbUser, dbPassword);
      String selectShipsSql = "SELECT * FROM ships WHERE star_id IS NOT NULL";
      PreparedStatement shipsPreparedStatement = connection.prepareStatement(selectShipsSql);
      ResultSet shipsResultSet = shipsPreparedStatement.executeQuery();
      
      while (shipsResultSet.next()) {
        // Retrieve data from the result set
        String shipId = shipsResultSet.getString("id");
        Double health = shipsResultSet.getDouble("health");
        String starId = shipsResultSet.getString("star_id");
        System.out.println("Ship (" + health + ") -*- " + starId);
        String selectStarSql = "SELECT * FROM stars WHERE id = '" + starId + "'";
        PreparedStatement starPreparedStatement = connection.prepareStatement(selectStarSql);
        ResultSet starResultSet = starPreparedStatement.executeQuery();
        if(starResultSet.next()) {
          Double luminosity = starResultSet.getDouble("luminosity");
          System.out.println("Star luminosity: " + luminosity);
          double lumLog = Math.log(luminosity) / Math.log(2);
          double damage = 0.1 * (lumLog > 0 ? 1 + lumLog : 1 / (1 - lumLog));
          System.out.println("L: " + luminosity + " => D: " + damage);
          if (health > 0) {
            Double decreasedHealth = health - damage;
            String updateShipSql = "UPDATE ships SET health = ? WHERE id = '" + shipId + "'";
            PreparedStatement updatePreparedStatement = connection.prepareStatement(updateShipSql);
            updatePreparedStatement.setDouble(1, decreasedHealth);
            updatePreparedStatement.executeUpdate();
            System.out.println("Ship (" + health + ") => (" + decreasedHealth + ")");
          }
        }
        count++;
      }
        
    } catch (SQLException e) {
        // Handle database-related exceptions
        e.printStackTrace();
    }

    LambdaLogger logger = context.getLogger();
    logger.log("Updated " + count + " ships");
    return "UPDATED " + count + " SHIPS";
  }
}
