package fr.apside.entretien.hibernate;

import fr.apside.entretien.hibernate.domaine.Country;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.boot.MetadataSources;
import org.hibernate.boot.registry.StandardServiceRegistry;
import org.hibernate.boot.registry.StandardServiceRegistryBuilder;

public class CountryService {

    protected SessionFactory sessionFactory;


    public void setup() {

        final StandardServiceRegistry registry = new StandardServiceRegistryBuilder()
                .configure()
                .build();
        try {
            sessionFactory = new MetadataSources(registry).buildMetadata().buildSessionFactory();
        } catch (Exception ex) {
            StandardServiceRegistryBuilder.destroy(registry);
        }
    }

    public void count(){
        Session session = sessionFactory.openSession();
        session.beginTransaction();

        System.out.println(session.createQuery("FROM Country").getResultList().size()+ " pays");

        session.getTransaction().commit();
        session.close();
    }

    public void exit() {
        sessionFactory.close();
    }

}
