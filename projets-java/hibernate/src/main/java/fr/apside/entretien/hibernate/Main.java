package fr.apside.entretien.hibernate;

public class Main {

    public static void main(String[] args) {

        CountryService service = new CountryService();

        service.setup();
        service.count();
        service.exit();
    }

}
